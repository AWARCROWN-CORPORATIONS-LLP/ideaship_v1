<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");

require_once 'config.php';

$username = $_GET['username'] ?? '';
$cursorId = isset($_GET['cursorId']) ? intval($_GET['cursorId']) : null;

if (empty($username)) {
    echo json_encode(["error" => "Username is required"]);
    exit;
}

// Fetch user_id for username
$stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
$stmt->execute([$username]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    echo json_encode(["error" => "User not found"]);
    exit;
}

$userId = $user['id'];

// Build SQL for shared posts
$sql = "
    SELECT p.*, u.username, u.profile_picture,
           IFNULL(l.user_id, NULL) AS is_liked
    FROM shares s
    JOIN posts p ON p.post_id = s.post_id
    JOIN users u ON u.id = p.user_id
    LEFT JOIN likes l ON l.post_id = p.post_id AND l.user_id = :uid
    WHERE s.user_id = :uid
";

$params = [":uid" => $userId];

// Cursor pagination (load older shares)
if ($cursorId) {
    $sql .= " AND s.share_id < :cursorId";
    $params[":cursorId"] = $cursorId;
}

$sql .= " ORDER BY s.share_id DESC LIMIT 10";

$stmt = $pdo->prepare($sql);
$stmt->execute($params);

$posts = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Determine next cursor
$nextCursor = null;
if (count($posts) > 0) {
    $last = end($posts);
    $nextCursor = $last['share_id'];
}

echo json_encode([
    "posts" => $posts,
    "nextCursorId" => $nextCursor
]);
?>
