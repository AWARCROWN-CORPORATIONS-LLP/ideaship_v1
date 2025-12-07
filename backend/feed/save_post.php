<?php
// save_post.php - Handles POST to save/unsave a post
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

require_once'config.php';

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

// Check if already saved
$stmt = $pdo->prepare("SELECT save_id FROM saves WHERE post_id = ? AND user_id = ?");
$stmt->execute([$post_id, $user_id]);
$existing_save = $stmt->fetch(PDO::FETCH_ASSOC);

try {
    if ($existing_save) {
        // Unsave: Delete the save and decrement count
        $stmt = $pdo->prepare("DELETE FROM saves WHERE post_id = ? AND user_id = ?");
        $stmt->execute([$post_id, $user_id]);

        $stmt = $pdo->prepare("UPDATE posts SET save_count = save_count - 1 WHERE post_id = ?");
        $stmt->execute([$post_id]);

        echo json_encode([
            'status' => 'success', 
            'message' => 'Post unsaved successfully', 
            'saved' => false
        ]);
    } else {
        // Save: Insert new save and increment count
        $stmt = $pdo->prepare("INSERT INTO saves (post_id, user_id, created_at) VALUES (?, ?, NOW())");
        $stmt->execute([$post_id, $user_id]);

        $stmt = $pdo->prepare("UPDATE posts SET save_count = save_count + 1 WHERE post_id = ?");
        $stmt->execute([$post_id]);

        echo json_encode([
            'status' => 'success', 
            'message' => 'Post saved successfully', 
            'is_saved' => true
        ]);
    }
} catch (PDOException $e) {
    echo json_encode(['status' => 'error', 'message' => 'Failed to save/unsave post']);
}
?>