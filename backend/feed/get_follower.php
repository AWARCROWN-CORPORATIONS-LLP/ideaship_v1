<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type');
require_once 'config.php';

try {
   
    // Get parameters
    $follower_id = isset($_GET['follower_id']) ? (int)$_GET['follower_id'] : null;
    $followed_id = isset($_GET['followed_id']) ? (int)$_GET['followed_id'] : null;

    // Validate parameters
    if ($follower_id === null || $followed_id === null || $follower_id <= 0 || $followed_id <= 0) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid or missing follower_id or followed_id']);
        exit;
    }

    // Query to check if follower follows the followed user
    $stmt = $pdo->prepare('SELECT COUNT(*) FROM follows WHERE follower_id = ? AND followed_id = ?');
    $stmt->execute([$follower_id, $followed_id]);
    $count = $stmt->fetchColumn();

    $is_following = $count > 0;

    // Return JSON response
    echo json_encode([
        'is_following' => $is_following
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error occurred']);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'An error occurred']);
}
?>