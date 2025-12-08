<?php
require_once 'config.php';
require_once '/home/v6gkv3hx0rj5/vendor/autoload.php';
header('Content-Type: application/json');

// -------------------------------------------------
// phpFastCache
// -------------------------------------------------
use Phpfastcache\Helper\Psr16Adapter;
use Phpfastcache\Config\ConfigurationOption;

try {
    $cacheConfig = new ConfigurationOption([
        'path' => __DIR__ . '/cache',
        'defaultTtl' => 60
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

// -------------------------------------------------
// Error Handling
// -------------------------------------------------
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL & ~E_DEPRECATED);

set_error_handler(function ($severity, $message, $file, $line) {
    error_log("PHP Error [$severity]: $message in $file:$line");
    if ($severity == E_ERROR) {
        http_response_code(500);
        echo json_encode(['error' => 'Server error']);
        exit;
    }
});

set_exception_handler(function ($e) {
    error_log("Uncaught Exception: {$e->getMessage()} at {$e->getFile()}:{$e->getLine()}");
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected error']);
    exit;
});

// -------------------------------------------------
// PDO Safe Mode
// -------------------------------------------------
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// -------------------------------------------------
// Image Upload Setup
// -------------------------------------------------
define('UPLOAD_DIR', __DIR__ . '/uploads/comments/');
define('MAX_FILE_SIZE', 10 * 1024 * 1024);

if (!file_exists(UPLOAD_DIR)) mkdir(UPLOAD_DIR, 0755, true);

// -------------------------------------------------
// Extract code (GET, POST, JSON)
// -------------------------------------------------
function extractCode() {
    $code = $_POST['code'] ?? ($_GET['code'] ?? null);


    if ($_SERVER['REQUEST_METHOD'] === 'POST') {

        if (!empty($_POST['code'])) return trim($_POST['code']);

        $json = json_decode(file_get_contents("php://input"), true);
        if (!empty($json['code'])) return trim($json['code']);
    }

    return $code ? trim($code) : null;
}
function handleImageUpload($image, $threadId, $commentId) {
    $ext = pathinfo($image['name'], PATHINFO_EXTENSION);
    $ext = strtolower($ext);

    $allowed = ['jpg','jpeg','png','gif','webp'];

    if (!in_array($ext, $allowed)) {
        throw new InvalidArgumentException("Unsupported image format");
    }

    $folder = UPLOAD_DIR . $threadId . "/";
    if (!file_exists($folder)) {
        mkdir($folder, 0755, true);
    }

    $filename = "comment_{$commentId}_" . time() . "." . $ext;
    $path = $folder . $filename;

    if (!move_uploaded_file($image['tmp_name'], $path)) {
        throw new RuntimeException("Image upload failed");
    }

    return "$filename";
}


// -------------------------------------------------
// Main Logic
// -------------------------------------------------
try {
    $method   = $_SERVER['REQUEST_METHOD'];
    $threadId = isset($_GET['id']) ? (int)$_GET['id'] : 0;
    $username = $_GET['username'] ?? ($_POST['username'] ?? null);


    $code     = extractCode();

    if (!$threadId) throw new InvalidArgumentException("Missing thread_id");
    if (!$username) throw new InvalidArgumentException("Missing username");

    // Load thread
    $threadStmt = $pdo->prepare("SELECT * FROM threads WHERE thread_id = ?");
    $threadStmt->execute([$threadId]);
    $thread = $threadStmt->fetch(PDO::FETCH_ASSOC);

    if (!$thread) throw new RuntimeException("Thread not found");

    // Load user
    $userStmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $userStmt->execute([$username]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) throw new RuntimeException("User not found");

    $userId    = (int)$user['id'];
    $creatorId = (int)$thread['created_by'];

    // ---------------------------------------------------------
    // 🔐 PRIVATE THREAD ACCESS CONTROL (Creator bypasses code)
    // ---------------------------------------------------------
    if ($thread['visibility'] === 'private') {

        if ($userId !== $creatorId) {

            if (!$code || strcmp($code, $thread['invite_code']) !== 0) {
                throw new RuntimeException("Access denied - invalid code");
            }
        }
    }

    // ---------------------------------------------------------
    // GET → Fetch Comments
    // ---------------------------------------------------------
    if ($method === 'GET') {

        $cacheKey = "thread_comments_$threadId";

        if ($cache->has($cacheKey)) {
            $c = $cache->get($cacheKey);
            $c['cached'] = true;
            echo json_encode($c);
            exit;
        }

        $stmt = $pdo->prepare("
            SELECT tc.comment_id, tc.parent_comment_id, tc.comment_body, tc.image_url,
                   tc.created_at, u.username AS commenter_username
            FROM thread_comments tc
            JOIN users u ON tc.commented_by = u.id
            WHERE tc.thread_id = ?
            ORDER BY tc.created_at ASC
        ");
        $stmt->execute([$threadId]);
        $comments = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Nest comments
        $map = [];
        foreach ($comments as &$c) {
            $c['replies'] = [];
            $map[$c['comment_id']] = &$c;
        }

        $nested = [];
        foreach ($map as &$c) {
            if ($c['parent_comment_id'] === null) {
                $nested[] = &$c;
            } else if (isset($map[$c['parent_comment_id']])) {
                $map[$c['parent_comment_id']]['replies'][] = &$c;
            }
        }

        $response = [
            'comments' => $nested,
            'comment_count' => (int)$thread['comment_count'],
            'cached' => false
        ];

        $cache->set($cacheKey, $response, 60);
        echo json_encode($response);
        exit;
    }

    // ---------------------------------------------------------
    // POST → Add Comment
    // ---------------------------------------------------------
    if ($method === 'POST') {

        $contentType = $_SERVER['CONTENT_TYPE'] 
    ?? $_SERVER['HTTP_CONTENT_TYPE'] 
    ?? '';

$contentType = $_SERVER['CONTENT_TYPE'] 
    ?? $_SERVER['HTTP_CONTENT_TYPE'] 
    ?? '';

$isMultipart = stripos($contentType, 'multipart/form-data') !== false;


        if ($isMultipart) {
            $body     = trim($_POST['body'] ?? '');
            $parentId = (int)($_POST['parent_id'] ?? 0);
            $image    = $_FILES['image'] ?? null;
        } else {
            $json = json_decode(file_get_contents("php://input"), true);
            $body     = trim($json['body'] ?? '');
            $parentId = (int)($json['parent_id'] ?? 0);
            $image    = null;
        }

        if ($body === '' && !$image) {
            throw new InvalidArgumentException("Comment body or image required");
        }

        // Parent ID check
        if ($parentId > 0) {
            $p = $pdo->prepare("SELECT comment_id FROM thread_comments WHERE comment_id = ? AND thread_id = ?");
            $p->execute([$parentId, $threadId]);
            if (!$p->fetch()) throw new InvalidArgumentException("Invalid parent ID");
        }

        $pdo->beginTransaction();

        // Insert comment
        $ins = $pdo->prepare("
            INSERT INTO thread_comments (thread_id, parent_comment_id, commented_by, comment_body, image_url)
            VALUES (?, ?, ?, ?, NULL)
        ");
        $ins->execute([$threadId, $parentId ?: null, $userId, $body]);

        $newId = $pdo->lastInsertId();
        $imageUrl = null;

        // Upload image
        if ($image && $image['error'] === UPLOAD_ERR_OK) {
            $imageUrl = handleImageUpload($image, $threadId, $newId);
            $pdo->prepare("UPDATE thread_comments SET image_url = ? WHERE comment_id = ?")
                ->execute([$imageUrl, $newId]);
        }

        // Update count
        $pdo->prepare("UPDATE threads SET comment_count = comment_count + 1 WHERE thread_id = ?")
            ->execute([$threadId]);

        $pdo->commit();

        // Clear cache
        $cache->delete("thread_comments_$threadId");

        // Fetch new comment
        $stmt = $pdo->prepare("
            SELECT tc.comment_id, tc.parent_comment_id, tc.comment_body, tc.image_url,
                   tc.created_at, u.username AS commenter_username
            FROM thread_comments tc
            JOIN users u ON tc.commented_by = u.id
            WHERE tc.comment_id = ?
        ");
        $stmt->execute([$newId]);
        $comment = $stmt->fetch(PDO::FETCH_ASSOC);

        echo json_encode([
            'success' => true,
            'new_comment' => $comment,
            'updated_comment_count' => (int)$thread['comment_count'] + 1
        ]);
        exit;
    }

    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);

} catch (Throwable $e) {

    if ($pdo->inTransaction()) $pdo->rollBack();

    $status = $e instanceof InvalidArgumentException ? 400 :
              ($e instanceof RuntimeException ? 403 : 500);

    http_response_code($status);
    echo json_encode(['error' => $e->getMessage()]);
}
?>
