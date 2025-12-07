<?php
header('Content-Type: application/json; charset=UTF-8');
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");
header("Expires: 0");

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL & ~E_DEPRECATED);

set_error_handler(function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

// -------------------------------------------------------
// Dependencies
// -------------------------------------------------------
require_once '/home/v6gkv3hx0rj5/vendor/autoload.php';
require_once 'config.php';

use Phpfastcache\Helper\Psr16Adapter;
use Phpfastcache\Config\ConfigurationOption;

// -------------------------------------------------------
// Error Logger
// -------------------------------------------------------
function logErrorDetailed($context, $exception)
{
    $logFile = __DIR__ . '/error_detailed.log';
    $timestamp = date('Y-m-d H:i:s');

    $message = sprintf("[%s] [%s] %s in %s:%d\nStack trace:\n%s\n\n",
        $timestamp,
        strtoupper($context),
        $exception->getMessage(),
        $exception->getFile(),
        $exception->getLine(),
        $exception->getTraceAsString()
    );

    file_put_contents($logFile, $message, FILE_APPEND);
    error_log($message);
}

// -------------------------------------------------------
// JSON Response Helper
// -------------------------------------------------------
function safeResponse($data = [], $code = 200)
{
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit();
}

// -------------------------------------------------------
// Cache Initialization
// -------------------------------------------------------
try {
    $config = new ConfigurationOption([
        'path' => __DIR__ . '/cache',
        'defaultTtl' => 45
    ]);

    $cache = new Psr16Adapter('Files', $config);
} catch (Throwable $e) {
    logErrorDetailed('CACHE_INIT', $e);

    // dummy fallback cache
    $cache = new class {
        function has($k) { return false; }
        function get($k) { return null; }
        function set($k, $v, $t = null) {}
    };
}

// -------------------------------------------------------
// Utility
// -------------------------------------------------------
function getCacheKey($username, $cursorId)
{
    return "posts_{$username}_cursor_" . ($cursorId ?: 'start');
}

function queueHotScoreUpdate($post_id)
{
    try {
        file_put_contents(__DIR__ . '/hot_score_queue.txt', $post_id . "\n", FILE_APPEND | LOCK_EX);
    } catch (Exception $e) {
        logErrorDetailed('QUEUE_WRITE', $e);
    }
}

function decryptData($data)
{
    try {
        if (!$data) return null;
        $decoded = base64_decode($data);
        if ($decoded === false || strpos($decoded, "::") === false) return null;

        list($enc, $iv) = explode("::", $decoded, 2);
        return openssl_decrypt($enc, "AES-256-CBC", base64_decode("7/bUxXBcXrgqyASvQSbLSKNce+rvWJt0botpIrA4poQ="), 0, $iv);
    } catch (Exception $e) {
        logErrorDetailed('DECRYPT', $e);
        return null;
    }
}

// -------------------------------------------------------
// Input Validation
// -------------------------------------------------------
try {
    $username = $_GET['username'] ?? '';
    if (empty($username)) safeResponse(['error' => 'Username required'], 400);

    $cursorId = isset($_GET['cursorId']) ? (int)$_GET['cursorId'] : null;
    if ($cursorId !== null && $cursorId < 0) safeResponse(['error' => 'Invalid cursorId'], 400);
} catch (Exception $e) {
    logErrorDetailed('VALIDATION', $e);
    safeResponse(['error' => 'Invalid input format'], 400);
}

// -------------------------------------------------------
// Try Cache First
// -------------------------------------------------------
try {
    $cacheKey = getCacheKey($username, $cursorId);

    if ($cache->has($cacheKey)) {
        $cached = $cache->get($cacheKey);
        if ($cached) {
            $cached['cached'] = true;
            safeResponse($cached, 200);
        }
    }
} catch (Exception $e) {
    logErrorDetailed('CACHE_READ', $e);
}

// -------------------------------------------------------
// Fetch User
// -------------------------------------------------------
try {
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = :u LIMIT 1");
    $stmt->execute(['u' => $username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) safeResponse(['error' => 'User not found'], 404);

    $user_id = (int)$user['id'];
} catch (Exception $e) {
    logErrorDetailed('USER_FETCH', $e);
    safeResponse(['error' => 'Database error'], 500);
}

// -------------------------------------------------------
// Fetch Posts (FIXED TIMEZONE)
// -------------------------------------------------------
try {
    $limit = 10;

    $sql = "
        SELECT 
            p.post_id,
            p.user_id,
            p.content,

            -- CORRECT: Do NOT convert timezone. DB is already IST.
            DATE_FORMAT(p.created_at, '%Y-%m-%dT%H:%i:%s+05:30') AS created_at,

            p.media_url,
            p.like_count,
            p.comment_count,
            p.share_count,
            p.hot_score,

            u.username,
            COALESCE(u.profile_picture, 'default-profile.png') AS profile_picture

        FROM posts p
        JOIN users u ON p.user_id = u.id

        LEFT JOIN post_reports r
            ON p.post_id = r.post_id AND r.reporter_username = :username

        WHERE r.post_id IS NULL
          AND p.visibility = 'public'
    ";

    if ($cursorId) $sql .= " AND p.post_id < :cursor_id";

    $sql .= " ORDER BY p.hot_score DESC, p.created_at DESC LIMIT :limit";

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':username', $username);

    if ($cursorId) $stmt->bindValue(':cursor_id', $cursorId, PDO::PARAM_INT);

    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();

    $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Exception $e) {
    logErrorDetailed('POST_FETCH', $e);
    safeResponse(['error' => 'Failed to fetch posts'], 500);
}

// -------------------------------------------------------
// Fetch Liked Posts
// -------------------------------------------------------
$likedPosts = [];
try {
    $postIds = array_column($posts, 'post_id');

    if ($postIds) {
        $inQ = implode(',', array_fill(0, count($postIds), '?'));

        $likeStmt = $pdo->prepare("SELECT post_id FROM post_likes WHERE user_id = ? AND post_id IN ($inQ)");
        $likeStmt->execute(array_merge([$user_id], $postIds));
        $likedPosts = $likeStmt->fetchAll(PDO::FETCH_COLUMN);
    }
} catch (Exception $e) {
    logErrorDetailed('LIKED_POSTS', $e);
}

// -------------------------------------------------------
// Final Processing
// -------------------------------------------------------
try {
    foreach ($posts as &$post) {

        queueHotScoreUpdate($post['post_id']);

        // decrypt media
        if (!empty($post['media_url'])) {
            $dec = decryptData($post['media_url']);

            if ($dec) {
                $fullPath = $_SERVER['DOCUMENT_ROOT'] . '/feed/' . $dec;
                $post['media_url'] = file_exists($fullPath)
                    ? '/feed/' . $dec
                    : '/feed/Posts/default-image.png';
            } else {
                $post['media_url'] = '/feed/Posts/default-image.png';
            }
        } else {
            $post['media_url'] = '/feed/Posts/default-image.png';
        }

        // like state
        $post['is_liked'] = in_array($post['post_id'], $likedPosts);
    }

    $nextCursorId = !empty($posts) ? end($posts)['post_id'] : null;

    $response = [
        'posts' => $posts,
        'nextCursorId' => $nextCursorId,
        'cached' => false
    ];

    $cache->set($cacheKey, $response, 45);

    safeResponse($response, 200);

} catch (Exception $e) {
    logErrorDetailed('POST_PROCESS', $e);
    safeResponse(['error' => 'Unexpected server error'], 500);
}

?>
