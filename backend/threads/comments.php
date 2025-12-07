<?php
require_once 'config.php';
require_once '/home/v6gkv3hx0rj5/vendor/autoload.php';
header('Content-Type: application/json');

// -------------------------------
// ✅ phpFastCache Integration
// -------------------------------
use Phpfastcache\Helper\Psr16Adapter;
use Phpfastcache\Config\ConfigurationOption;

try {
    $cacheConfig = new ConfigurationOption([
        'path' => __DIR__ . '/cache',
        'defaultTtl' => 60 // Cache comments for 60 seconds
    ]);
    $cache = new Psr16Adapter('Files', $cacheConfig);
} catch (Throwable $e) {
    error_log("[CACHE_INIT] " . $e->getMessage());
    $cache = new class {
        function has($k){ return false; }
        function get($k){ return null; }
        function set($k,$v,$t=null){}
        function delete($k){}
    };
}

// -------------------------------
// ✅ Advanced Error Handling Setup
// -------------------------------
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL & ~E_DEPRECATED);

set_error_handler(function ($severity, $message, $file, $line) {
    $logMessage = sprintf("[%s] PHP Error [%d]: %s in %s:%d\n", date('Y-m-d H:i:s'), $severity, $message, $file, $line);
    error_log($logMessage);
    if (in_array($severity, [E_ERROR, E_USER_ERROR])) {
        http_response_code(500);
        echo json_encode(['error' => 'A server error occurred.']);
        exit;
    }
});

set_exception_handler(function ($e) {
    $logMessage = sprintf("[%s] Uncaught Exception: %s in %s:%d\nStack trace:\n%s\n", date('Y-m-d H:i:s'), $e->getMessage(), $e->getFile(), $e->getLine(), $e->getTraceAsString());
    error_log($logMessage);
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected internal error']);
    exit;
});

// -------------------------------
// ✅ Ensure PDO Configured Safely
// -------------------------------
try {
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (Throwable $pdoErr) {
    error_log("[" . date('Y-m-d H:i:s') . "] PDO Attribute Error: " . $pdoErr->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Database configuration failed']);
    exit;
}

// -------------------------------
// ✅ Image Upload Configuration
// -------------------------------
define('UPLOAD_DIR', __DIR__ . '/uploads/comments/');
define('MAX_FILE_SIZE', 10 * 1024 * 1024); // 10MB
define('ALLOWED_EXTENSIONS', ['jpg', 'jpeg', 'png', 'gif', 'webp']);

// Create upload directory if it doesn't exist
if (!file_exists(UPLOAD_DIR)) {
    mkdir(UPLOAD_DIR, 0755, true);
}

// -------------------------------
// ✅ Helper Function: Handle Image Upload
// -------------------------------
function handleImageUpload($file, $threadId, $commentId) {
    if (!isset($file['error']) || $file['error'] !== UPLOAD_ERR_OK) {
        return null;
    }

    // Validate file size
    if ($file['size'] > MAX_FILE_SIZE) {
        throw new InvalidArgumentException("Image file is too large (max 10MB)");
    }

    // Validate file type
    $fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($fileExtension, ALLOWED_EXTENSIONS)) {
        throw new InvalidArgumentException("Invalid file type. Allowed: " . implode(', ', ALLOWED_EXTENSIONS));
    }

    // Validate MIME type
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mimeType = finfo_file($finfo, $file['tmp_name']);
    finfo_close($finfo);
    
    $allowedMimes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!in_array($mimeType, $allowedMimes)) {
        throw new InvalidArgumentException("Invalid MIME type");
    }

    // Generate unique filename
    $filename = 'comment_' . $threadId . '_' . $commentId . '_' . time() . '_' . uniqid() . '.' . $fileExtension;
    $filepath = UPLOAD_DIR . $filename;

    // Move uploaded file
    if (!move_uploaded_file($file['tmp_name'], $filepath)) {
        throw new RuntimeException("Failed to save uploaded image");
    }

    // Return relative path for database storage
    return 'comments/' . $filename;
}

// -------------------------------
// ✅ Main Logic
// -------------------------------
try {
    $method   = $_SERVER['REQUEST_METHOD'];
    $threadId = isset($_GET['id']) ? (int)$_GET['id'] : 0;
    $username = $_GET['username'] ?? null;
    $code     = $_GET['code'] ?? null;

    // Log every request
    error_log(sprintf("[%s] Request: %s id=%s username=%s", date('Y-m-d H:i:s'), $method, $threadId, $username));

    if (!$threadId) {
        throw new InvalidArgumentException("Missing thread_id");
    }

    // -------------------------------
    // ✅ Validate Thread Access
    // -------------------------------
    $threadStmt = $pdo->prepare("SELECT * FROM threads WHERE thread_id = ?");
    $threadStmt->execute([$threadId]);
    $thread = $threadStmt->fetch(PDO::FETCH_ASSOC);
    if (!$thread) {
        throw new RuntimeException("Thread not found: $threadId");
    }

    if ($thread['visibility'] === 'private' && $code !== $thread['invite_code']) {
        throw new RuntimeException("Access denied - invalid code");
    }

    // -------------------------------
    // ✅ Handle GET Request (Cached)
    // -------------------------------
    if ($method === 'GET') {
        $cacheKey = "thread_comments_" . $threadId;

        if ($cache->has($cacheKey)) {
            $cachedResponse = $cache->get($cacheKey);
            $cachedResponse['cached'] = true;
            echo json_encode($cachedResponse);
            exit;
        }

        $allCommentsStmt = $pdo->prepare("
            SELECT 
                tc.comment_id,
                tc.parent_comment_id,
                tc.comment_body,
                tc.image_url,
                tc.created_at,
                u.username AS commenter_username
            FROM thread_comments tc
            JOIN users u ON tc.commented_by = u.id
            WHERE tc.thread_id = ?
            ORDER BY tc.created_at ASC
        ");
        $allCommentsStmt->execute([$threadId]);
        $allComments = $allCommentsStmt->fetchAll(PDO::FETCH_ASSOC);

        // --- Build Nested Comment Tree ---
        $commentMap = [];
        foreach ($allComments as &$comment) {
            $comment['replies'] = [];
            $commentMap[$comment['comment_id']] = &$comment;
        }
        unset($comment);

        $nestedComments = [];
        foreach ($commentMap as &$comment) {
            if ($comment['parent_comment_id'] === null) {
                $nestedComments[] = &$comment;
            } else {
                if (isset($commentMap[$comment['parent_comment_id']])) {
                    $commentMap[$comment['parent_comment_id']]['replies'][] = &$comment;
                }
            }
        }
        unset($comment);

        $response = [
            'comments' => $nestedComments,
            'comment_count' => (int)($thread['comment_count'] ?? 0),
            'cached' => false
        ];

        // ✅ Save to cache
        try {
            $cache->set($cacheKey, $response, 60);
        } catch (Throwable $e) {
            error_log("[CACHE_WRITE] " . $e->getMessage());
        }

        echo json_encode($response);
        exit;
    }

    // -------------------------------
    // ✅ Handle POST Request (Support Multipart for Images)
    // -------------------------------
    if ($method === 'POST') {
        // Check if request is multipart/form-data (for image uploads)
        $isMultipart = strpos($_SERVER['CONTENT_TYPE'] ?? '', 'multipart/form-data') !== false;
        
        if ($isMultipart) {
            // Handle multipart form data (with image)
            $body = trim($_POST['body'] ?? '');
            $parentId = (int)($_POST['parent_id'] ?? 0);
            $username = trim($_POST['username'] ?? '');
            $code = $_POST['code'] ?? null;
            $imageFile = $_FILES['image'] ?? null;
        } else {
            // Handle JSON data (without image)
            $input = json_decode(file_get_contents('php://input'), true);
            $body = trim($input['body'] ?? '');
            $parentId = (int)($input['parent_id'] ?? 0);
            $username = trim($input['username'] ?? '');
            $code = $input['code'] ?? null;
            $imageFile = null;
        }

        // Validate: either body or image must be present
        if (empty($body) && !$imageFile) {
            throw new InvalidArgumentException("Comment body or image is required");
        }

        if (!$username) {
            throw new InvalidArgumentException("Missing username");
        }

        if ($thread['visibility'] === 'private' && $code !== $thread['invite_code']) {
            throw new RuntimeException("Access denied - invalid code");
        }

        $userStmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
        $userStmt->execute([$username]);
        $user = $userStmt->fetch(PDO::FETCH_ASSOC);
        if (!$user) {
            throw new RuntimeException("User not found: $username");
        }

        if ($parentId > 0) {
            $parentStmt = $pdo->prepare("SELECT comment_id FROM thread_comments WHERE comment_id = ? AND thread_id = ?");
            $parentStmt->execute([$parentId, $threadId]);
            if (!$parentStmt->fetch()) {
                throw new InvalidArgumentException("Invalid parent comment ID: $parentId");
            }
        }

        $pdo->beginTransaction();

        // Insert comment first (without image_url, we'll update it)
        $insertStmt = $pdo->prepare("
            INSERT INTO thread_comments (thread_id, parent_comment_id, commented_by, comment_body, image_url) 
            VALUES (?, ?, ?, ?, NULL)
        ");
        $insertStmt->execute([$threadId, $parentId ?: null, $user['id'], $body]);
        $newCommentId = $pdo->lastInsertId();

        // Handle image upload if present
        $imageUrl = null;
        if ($imageFile && isset($imageFile['error']) && $imageFile['error'] === UPLOAD_ERR_OK) {
            try {
                $imageUrl = handleImageUpload($imageFile, $threadId, $newCommentId);
                
                // Update comment with image URL
                if ($imageUrl) {
                    $updateStmt = $pdo->prepare("UPDATE thread_comments SET image_url = ? WHERE comment_id = ?");
                    $updateStmt->execute([$imageUrl, $newCommentId]);
                }
            } catch (Exception $imgErr) {
                // Rollback transaction if image upload fails
                $pdo->rollBack();
                throw new RuntimeException("Image upload failed: " . $imgErr->getMessage());
            }
        }

        $pdo->prepare("UPDATE threads SET comment_count = comment_count + 1 WHERE thread_id = ?")
            ->execute([$threadId]);

        // --- Notification (for thread owner) ---
        if ($parentId === 0 && $thread['created_by'] !== $user['id']) {
            $notifStmt = $pdo->prepare("
                INSERT INTO threads_notifications (user_id, type, thread_id, sender_id, message)
                VALUES (?, 'new_comment', ?, ?, ?)
            ");
            $message = $imageUrl ? "New comment with image on your thread" : "New comment on your thread: " . substr($body, 0, 50);
            $notifStmt->execute([$thread['created_by'], $threadId, $user['id'], $message]);

            try {
                $data = ['thread_id' => $threadId, 'type' => 'new_comment'];
                sendFCMNotification(
                    $pdo,
                    $thread['created_by'],
                    'New Comment on Your Thread',
                    $imageUrl ? "Someone commented with an image on '{$thread['title']}'" : "Someone commented on '{$thread['title']}'",
                    $data
                );
            } catch (Throwable $fcmErr) {
                error_log(sprintf("[%s] FCM Send Error: %s\n", date('Y-m-d H:i:s'), $fcmErr->getMessage()));
            }
        }

        $pdo->commit();

        // --- Invalidate Cache ---
        try {
            $cacheKey = "thread_comments_" . $threadId;
            $cache->delete($cacheKey);
        } catch (Throwable $e) {
            error_log("[CACHE_DELETE] " . $e->getMessage());
        }

        // --- Fetch inserted comment ---
        $newCommentStmt = $pdo->prepare("
            SELECT 
                tc.comment_id,
                tc.parent_comment_id,
                tc.comment_body,
                tc.image_url,
                tc.created_at,
                u.username AS commenter_username
            FROM thread_comments tc
            JOIN users u ON tc.commented_by = u.id
            WHERE tc.comment_id = ?
        ");
        $newCommentStmt->execute([$newCommentId]);
        $newComment = $newCommentStmt->fetch(PDO::FETCH_ASSOC);

        echo json_encode([
            'success' => true,
            'new_comment' => $newComment,
            'updated_comment_count' => (int)($thread['comment_count'] ?? 0) + 1
        ]);
        exit;
    }

    // Unsupported Method
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);

} catch (InvalidArgumentException $e) {
    error_log("[" . date('Y-m-d H:i:s') . "] Validation Error: " . $e->getMessage());
    http_response_code(400);
    echo json_encode(['error' => $e->getMessage()]);

} catch (RuntimeException $e) {
    error_log("[" . date('Y-m-d H:i:s') . "] Runtime Error: " . $e->getMessage());
    http_response_code(404);
    echo json_encode(['error' => $e->getMessage()]);

} catch (PDOException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log("[" . date('Y-m-d H:i:s') . "] Database Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Database operation failed']);

} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log("[" . date('Y-m-d H:i:s') . "] Fatal Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error']);
}
?>
