<?php
require_once 'config.php';
require_once '/home/v6gkv3hx0rj5/vendor/autoload.php';
header('Content-Type: application/json; charset=UTF-8');

// -------------------------------
// ✅ phpFastCache Integration
// -------------------------------
use Phpfastcache\Helper\Psr16Adapter;
use Phpfastcache\Config\ConfigurationOption;

try {
    $cacheConfig = new ConfigurationOption([
        'path' => __DIR__ . '/cache',
        'defaultTtl' => 60 // cache threads for 60 seconds
    ]);
    $cache = new Psr16Adapter('Files', $cacheConfig);
} catch (Throwable $e) {
    error_log("[CACHE_INIT] " . $e->getMessage());
    // Fallback to dummy cache to prevent crash
    $cache = new class {
        function has($k){ return false; }
        function get($k){ return null; }
        function set($k,$v,$t=null){}
        function delete($k){}
    };
}

// -------------------------------
// ✅ Error Handling
// -------------------------------
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL & ~E_DEPRECATED);

set_error_handler(function ($severity, $message, $file, $line) {
    $msg = sprintf("[%s] PHP Error [%d]: %s in %s:%d\n", date('Y-m-d H:i:s'), $severity, $message, $file, $line);
    error_log($msg);
    if (in_array($severity, [E_ERROR, E_USER_ERROR])) {
        http_response_code(500);
        echo json_encode(['error' => 'A server error occurred.']);
        exit;
    }
});

set_exception_handler(function ($e) {
    $msg = sprintf("[%s] Uncaught Exception: %s in %s:%d\nStack trace:\n%s\n",
        date('Y-m-d H:i:s'), $e->getMessage(), $e->getFile(), $e->getLine(), $e->getTraceAsString()
    );
    error_log($msg);
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected internal error']);
    exit;
});

// -------------------------------
// ✅ Input Parameters
// -------------------------------
$category = $_GET['category'] ?? null;
$sort = $_GET['sort'] ?? 'recent'; // trending, recent, innovative
$username = $_GET['username'] ?? null; // For user's own threads
$limit = (int)($_GET['limit'] ?? 10);
$offset = (int)($_GET['offset'] ?? 0);
$limit = max(1, $limit);
$offset = max(0, $offset);

// Unique cache key
$cacheKey = "threads_" . md5(json_encode([$category, $sort, $username, $limit, $offset]));

// -------------------------------
// ✅ Return from Cache if available
// -------------------------------
try {
    if ($cache->has($cacheKey)) {
        $cachedData = $cache->get($cacheKey);
        if ($cachedData) {
            ob_clean();
            header('Content-Type: application/json; charset=UTF-8');
            echo trim(json_encode($cachedData, JSON_UNESCAPED_UNICODE));
            exit;
        }
    }
} catch (Throwable $e) {
    error_log("[CACHE_READ] " . $e->getMessage());
}

// -------------------------------
// ✅ Build SQL Query
// -------------------------------
try {
    $sql = "SELECT
                t.thread_id,
                t.title,
                t.body,
                t.visibility,
                t.created_at,
                t.inspired_count,
                t.comment_count,
                t.collab_count,
                t.invite_code,
                tc.name AS category_name,
                u.username AS creator_username,
                ur.role AS creator_role
            FROM threads t
            JOIN thread_categories tc ON t.category_id = tc.category_id
            JOIN users u ON t.created_by = u.id
            LEFT JOIN user_role ur ON u.id = ur.user_id
            WHERE t.status = 'active'";
    $params = [];

    // Filter by username
    if ($username) {
        $sql .= " AND t.created_by = (SELECT id FROM users WHERE username = ?)";
        $params[] = $username;
    } else {
        $sql .= " AND t.visibility = ?";
        $params[] = 'public';
    }

    // Filter by category
    if ($category) {
        $sql .= " AND t.category_id = (SELECT category_id FROM thread_categories WHERE name = ?)";
        $params[] = $category;
    }

    // Sorting logic
    if ($sort === 'trending') {
        $sql .= " ORDER BY t.inspired_count DESC, t.collab_count DESC, t.created_at DESC";
    } elseif ($sort === 'innovative') {
        $sql .= " ORDER BY (t.inspired_count + t.comment_count + t.collab_count) DESC";
    } else {
        $sql .= " ORDER BY t.created_at DESC";
    }

    $sql .= " LIMIT $limit OFFSET $offset";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $threads = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // -------------------------------
    // ✅ Fetch Tags
    // -------------------------------
    $threadIds = array_column($threads, 'thread_id');
    $tagMap = [];
    if (!empty($threadIds)) {
        $placeholders = implode(',', array_fill(0, count($threadIds), '?'));
        $tagSql = "SELECT tht.thread_id, tt.tag_name
                   FROM thread_tags tht
                   JOIN tags tt ON tht.tag_id = tt.tag_id
                   WHERE tht.thread_id IN ($placeholders)";
        $tagStmt = $pdo->prepare($tagSql);
        $tagStmt->execute($threadIds);
        while ($row = $tagStmt->fetch(PDO::FETCH_ASSOC)) {
            $tagMap[$row['thread_id']][] = $row['tag_name'];
        }
    }

    // -------------------------------
    // ✅ Format Output for Flutter
    // -------------------------------
    foreach ($threads as &$thread) {
        $thread['tags'] = $tagMap[$thread['thread_id']] ?? [];
        $thread['inspired_count'] = (int)($thread['inspired_count'] ?? 0);
        $thread['comment_count'] = (int)($thread['comment_count'] ?? 0);
        $thread['collab_count'] = (int)($thread['collab_count'] ?? 0);

        // Hide invite_code unless it's the user's own thread
        if (!$username) unset($thread['invite_code']);
    }

    // -------------------------------
    // ✅ Save to Cache
    // -------------------------------
    try {
        $cache->set($cacheKey, $threads, 60);
    } catch (Throwable $e) {
        error_log("[CACHE_WRITE] " . $e->getMessage());
    }

    // -------------------------------
    // ✅ Return Clean JSON Array (Flutter expects List)
    // -------------------------------
    ob_clean();
    header('Content-Type: application/json; charset=UTF-8');
    header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
    header('Pragma: no-cache');
    header('Expires: 0');
    echo trim(json_encode($threads, JSON_UNESCAPED_UNICODE));
    exit;

} catch (PDOException $e) {
    error_log("[" . date('Y-m-d H:i:s') . "] DB Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Database operation failed']);
    exit;
} catch (Throwable $e) {
    error_log("[" . date('Y-m-d H:i:s') . "] Fatal Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Unexpected server error']);
    exit;
}
?>
