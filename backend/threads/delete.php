<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$thread_id = isset($input['thread_id']) ? (int)$input['thread_id'] : 0;
$user_id = isset($input['user_id']) ? (int)$input['user_id'] : 0;
$username = isset($input['username']) ? trim($input['username']) : '';

if ($thread_id <= 0 || $user_id <= 0 || empty($username)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Missing required fields']);
    exit;
}
require'config.php';

// Verify user owns the thread
$stmt = $pdo->prepare('SELECT created_by FROM threads WHERE thread_id = ?');
$stmt->execute([$thread_id]);
$thread = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$thread) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Thread not found']);
    exit;
}

if ($thread['created_by'] != $user_id) {
    http_response_code(403);
    echo json_encode(['success' => false, 'error' => 'You are not the owner of this thread']);
    exit;
}

// Delete the thread (and optionally related comments, inspires, etc.)
try {
    $pdo->beginTransaction();

    // Delete related data first if needed (e.g., comments, inspires)
    // Example: $stmt = $pdo->prepare('DELETE FROM comments WHERE thread_id = ?'); $stmt->execute([$thread_id]);
    // Example: $stmt = $pdo->prepare('DELETE FROM inspires WHERE thread_id = ?'); $stmt->execute([$thread_id]);

    $stmt = $pdo->prepare('DELETE FROM threads WHERE thread_id = ?');
    $stmt->execute([$thread_id]);

    $pdo->commit();
    echo json_encode(['success' => true, 'message' => 'Thread deleted successfully']);
} catch (Exception $e) {
    $pdo->rollBack();
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Failed to delete thread']);
}
?>