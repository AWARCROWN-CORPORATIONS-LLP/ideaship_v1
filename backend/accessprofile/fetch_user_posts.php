<?php
header('Content-Type: application/json');
require_once 'config.php';

ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL);

define("ENCRYPTION_KEY", base64_decode("7/bUxXBcXrgqyASvQSbLSKNce+rvWJt0botpIrA4poQ="));
define("ENCRYPTION_METHOD", "AES-256-CBC");

function decryptData($data) {
    if (!$data) return null;
    $decoded = base64_decode($data);
    if ($decoded === false || strpos($decoded, "::") === false) return null;

    list($encrypted, $iv) = explode("::", $decoded, 2);
    return openssl_decrypt($encrypted, ENCRYPTION_METHOD, ENCRYPTION_KEY, 0, $iv) ?: null;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$username = $_GET['username'] ?? '';
$target_username = $_GET['target_username'] ?? '';
$action = $_GET['action'] ?? 'my_posts';
$cursorId = isset($_GET['cursorId']) ? intval($_GET['cursorId']) : null;
$limit = 10;

// Validate user
if (!$username) {
    echo json_encode(['error' => 'username is required']);
    exit;
}

// Fetch logged-in user ID
$stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
$stmt->execute([$username]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    echo json_encode(['error' => 'User not found']);
    exit;
}

$userId = $user['id'];

// **************************************************
// ACTION: MY POSTS
// **************************************************
if ($action === "my_posts") {

    if (!$target_username) $target_username = $username;

    // Get target profile user id
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $stmt->execute([$target_username]);
    $targetUser = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$targetUser) {
        echo json_encode(['error' => 'Target user not found']);
        exit;
    }

    $targetUserId = $targetUser['id'];

    $sql = "
        SELECT 
            p.post_id,
            p.user_id,
            u.username,
            u.profile_picture,
            p.content,
            p.media_url,
            p.created_at,
            p.like_count,
            p.comment_count
        FROM posts p
        JOIN users u ON u.id = p.user_id
        WHERE p.user_id = :targetUserId
    ";

    if ($cursorId) {
        $sql .= " AND p.post_id < :cursorId ";
    }

    $sql .= " ORDER BY p.post_id DESC LIMIT :limit";

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':targetUserId', $targetUserId, PDO::PARAM_INT);
}

// **************************************************
// ACTION: SAVED POSTS
// **************************************************
else if ($action === "saved_posts") {

    $sql = "
        SELECT 
            s.save_id,
            p.post_id,
            p.user_id,
            u.username,
            u.profile_picture,
            p.content,
            p.media_url,
            p.created_at,
            p.like_count,
            p.comment_count
        FROM saves s
        JOIN posts p ON p.post_id = s.post_id
        JOIN users u ON u.id = p.user_id
        WHERE s.user_id = :userId
    ";

    if ($cursorId) {
        $sql .= " AND s.save_id < :cursorId ";
    }

    $sql .= " ORDER BY s.save_id DESC LIMIT :limit";

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':userId', $userId, PDO::PARAM_INT);
}

if ($cursorId) {
    $stmt->bindValue(':cursorId', $cursorId, PDO::PARAM_INT);
}

$stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
$stmt->execute();

$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Format + decrypt media_url
$posts = array_map(function($row) {
    return [
        'post_id' => (int)$row['post_id'],
        'user_id' => (int)$row['user_id'],
        'username' => $row['username'],
        'profile_picture' => $row['profile_picture'],
        'content' => $row['content'],
        'media_url' => decryptData($row['media_url']),
        'created_at' => $row['created_at'],
        'like_count' => (int)$row['like_count'],
        'comment_count' => (int)$row['comment_count'],
    ];
}, $rows);

// Next cursor logic
if ($action === "saved_posts") {
    $nextCursorId = (count($rows) === $limit) ? end($rows)['save_id'] : null;
} else {
    $nextCursorId = (count($rows) === $limit) ? end($rows)['post_id'] : null;
}

echo json_encode([
    'success' => true,
    'action' => $action,
    'posts' => $posts,
    'nextCursorId' => $nextCursorId
]);
?>
