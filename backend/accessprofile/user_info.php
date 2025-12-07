<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'config.php';

// Function to get user ID by username
function getUserId($pdo, $username) {
    $stmt = $pdo->prepare('SELECT id FROM users WHERE username = ?');
    $stmt->execute([$username]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    return $result ? $result['id'] : null;
}

// Get parameters
$targetUsername = $_GET['target_username'] ?? null;
$currentUsername = $_GET['username'] ?? null;

if (!$targetUsername || !$currentUsername) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing target_username or username parameter']);
    exit;
}

// Validate current user
$currentUserId = getUserId($pdo, $currentUsername);
if (!$currentUserId) {
    http_response_code(401);
    echo json_encode(['error' => 'Current user not found']);
    exit;
}

// Fetch target user ID
$targetUserId = getUserId($pdo, $targetUsername);
if (!$targetUserId) {
    http_response_code(404);
    echo json_encode(['error' => 'Target user not found']);
    exit;
}

// Fetch user info with counts
$stmt = $pdo->prepare('
    SELECT username, profile_picture,
           posts_count,
           (SELECT COUNT(*) FROM follows WHERE followed_id = ?) as followers_count,
           (SELECT COUNT(*) FROM follows WHERE follower_id = ?) as following_count
    FROM users WHERE id = ?
');
$stmt->execute([$targetUserId, $targetUserId, $targetUserId]);

$userInfo = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$userInfo) {
    http_response_code(404);
    echo json_encode(['error' => 'User info not found']);
    exit;
}

// Check if current user is following target user
$stmt = $pdo->prepare('SELECT COUNT(*) FROM follows WHERE follower_id = ? AND followed_id = ?');
$stmt->execute([$currentUserId, $targetUserId]);
$isFollowing = $stmt->fetchColumn() > 0;

$userInfo['is_following'] = $isFollowing;

echo json_encode($userInfo);
?>