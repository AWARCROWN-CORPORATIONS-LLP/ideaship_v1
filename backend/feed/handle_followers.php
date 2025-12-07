<?php
header('Content-Type: application/json');
require_once 'config.php';
try {
   

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Invalid request method');
    }

    $follower_id = isset($_POST['follower_id']) ? (int)$_POST['follower_id'] : null;
    $followed_id = isset($_POST['followed_id']) ? (int)$_POST['followed_id'] : null;
    $action = isset($_POST['action']) ? $_POST['action'] : null;

    if (!$follower_id || !$followed_id || !in_array($action, ['follow', 'unfollow'])) {
        throw new Exception('Invalid parameters');
    }

    if ($follower_id === $followed_id) {
        throw new Exception('Cannot follow/unfollow yourself');
    }

    if ($action === 'follow') {
        // Check if already following
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM follows WHERE follower_id = ? AND followed_id = ?");
        $stmt->execute([$follower_id, $followed_id]);
        if ($stmt->fetchColumn() > 0) {
            throw new Exception('Already following this user');
        }

        // Insert follow relationship
        $stmt = $pdo->prepare("INSERT INTO follows (follower_id, followed_id, created_at) VALUES (?, ?, NOW())");
        $stmt->execute([$follower_id, $followed_id]);
        echo json_encode(['status' => 'success', 'message' => 'Followed successfully']);
    } else {
        // Delete follow relationship
        $stmt = $pdo->prepare("DELETE FROM follows WHERE follower_id = ? AND followed_id = ?");
        $stmt->execute([$follower_id, $followed_id]);
        if ($stmt->rowCount() > 0) {
            echo json_encode(['status' => 'success', 'message' => 'Unfollowed successfully']);
        } else {
            throw new Exception('Not following this user');
        }
    }
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
} finally {
    $pdo = null;
}
?>