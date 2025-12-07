<?php
// post_feature.php - Handles GET /post_feature/{token} to fetch post data
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');

require_once'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method']);
    exit;
}

// Get token from URL path (assuming routed as /post_feature/{token})
$token = isset($_GET['token']) ? trim($_GET['token']) : ''; // Adjust based on your routing, e.g., parse from path

if (empty($token)) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid token']);
    exit;
}

// Fetch share by token
$stmt = $pdo->prepare("SELECT post_id FROM shares WHERE token = ?");
$stmt->execute([$token]);
$share = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$share) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid or expired share link']);
    exit;
}

$post_id = $share['post_id'];

// Fetch post data (adjust fields as per your schema)
$stmt = $pdo->prepare("
    SELECT p.*, u.username, u.profile_picture 
    FROM posts p 
    JOIN users u ON p.user_id = u.id 
    WHERE p.post_id = ? AND p.is_deleted = 0
");
$stmt->execute([$post_id]);
$post = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$post) {
    echo json_encode(['status' => 'error', 'message' => 'Post not found']);
    exit;
}

// Optionally, include comments or other data
// For simplicity, just return post basics

echo json_encode([
    'status' => 'success', 
    'post' => $post,
    'deep_link' => 'awarcrown://post/' . $post_id // Example deep link scheme for app
]);
?>