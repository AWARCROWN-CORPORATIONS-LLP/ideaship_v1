<?php
require_once 'config.php';
header('Content-Type: application/json');


ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL);

try {
    $threadId = isset($_GET['id']) ? (int)$_GET['id'] : 0;
    $input = json_decode(file_get_contents('php://input'), true);
    $username = $input['username'] ?? null;
    $code = $input['code'] ?? $_GET['code'] ?? null; // For private

    if (!$threadId || !$username) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing fields']);
        exit;
    }

    // Fetch user
    $userStmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $userStmt->execute([$username]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    if (!$user) {
        http_response_code(404);
        echo json_encode(['error' => 'User not found']);
        exit;
    }

    // Check thread access
    $threadStmt = $pdo->prepare("SELECT visibility, invite_code FROM threads WHERE thread_id = ?");
    $threadStmt->execute([$threadId]);
    $thread = $threadStmt->fetch(PDO::FETCH_ASSOC);
    if (!$thread) {
        http_response_code(404);
        echo json_encode(['error' => 'Thread not found']);
        exit;
    }
    if ($thread['visibility'] === 'private' && $code !== $thread['invite_code']) {
        http_response_code(403);
        echo json_encode(['error' => 'Access denied - invalid code']);
        exit;
    }

    
    $checkStmt = $pdo->prepare("SELECT * FROM saved_threads WHERE user_id = ? AND thread_id = ?");
    $checkStmt->execute([$user['id'], $threadId]);

    if ($checkStmt->fetch()) {
     
        $delStmt = $pdo->prepare("DELETE FROM saved_threads WHERE user_id = ? AND thread_id = ?");
        $delStmt->execute([$user['id'], $threadId]);
        $action = 'unsaved';
    } else {
       
        $insStmt = $pdo->prepare("INSERT INTO saved_threads (user_id, thread_id) VALUES (?, ?)");
        $insStmt->execute([$user['id'], $threadId]);
        $action = 'saved';
    }

    echo json_encode(['success' => true, 'action' => $action]);

} catch (Exception $e) {
    error_log("Error in save.php: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Internal Server Error']);
}
?>