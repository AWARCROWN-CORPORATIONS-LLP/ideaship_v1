<?php
// share_post.php - Handles POST to create a share
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method']);
    exit;
}

$input = file_get_contents('php://input');
$parsedInput = [];
parse_str($input, $parsedInput);

$post_id = isset($parsedInput['post_id']) ? intval($parsedInput['post_id']) : 0;
$username = isset($parsedInput['username']) ? trim($parsedInput['username']) : '';

// Validation
if ($post_id <= 0 || empty($username)) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid post_id or username']);
    exit;
}

// Get user_id from username
$stmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
$stmt->execute([$username]);
$user = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$user) {
    echo json_encode(['status' => 'error', 'message' => 'User not found']);
    exit;
}

$user_id = $user['id'];

// Check if already shared by this user (prevent duplicates)
$stmt = $pdo->prepare("SELECT share_id FROM shares WHERE post_id = ? AND user_id = ?");
$stmt->execute([$post_id, $user_id]);
if ($stmt->fetch()) {
    // If already shared, perhaps return the existing token
    $stmt = $pdo->prepare("SELECT token FROM shares WHERE post_id = ? AND user_id = ?");
    $stmt->execute([$post_id, $user_id]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($existing) {
        $share_url = 'https://share.awarcrown.com/post_feature/' . $existing['token'];
        echo json_encode(['status' => 'success', 'message' => 'Post already shared', 'share_url' => $share_url]);
        exit;
    }
}

// Generate unique token (encrypted-like, using random bytes)
$token = bin2hex(random_bytes(16)); // 32 char hex token

// Insert share
try {
    $stmt = $pdo->prepare("INSERT INTO shares (post_id, user_id, token, created_at) VALUES (?, ?, ?, NOW())");
    $stmt->execute([$post_id, $user_id, $token]);

    // Update post share_count
    $stmt = $pdo->prepare("UPDATE posts SET share_count = share_count + 1 WHERE post_id = ?");
    $stmt->execute([$post_id]);

    $share_url = 'https://share.awarcrown.com/post_feature/' . $token;
    echo json_encode(['status' => 'success', 'message' => 'Post shared successfully', 'share_url' => $share_url]);
} catch (PDOException $e) {
    echo json_encode(['status' => 'error', 'message' => 'Failed to share post']);
}
?>