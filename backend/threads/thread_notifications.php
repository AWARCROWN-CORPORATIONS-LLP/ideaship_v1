<?php
require_once 'config.php';
header('Content-Type: application/json');


ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL);

try {
    $username = $_GET['username'] ?? null;
    $isRead = isset($_GET['read']) ? (bool)$_GET['read'] : null; // null = all, true = read, false = unread

    if (!$username) {
        http_response_code(400);
        echo json_encode(['error' => 'Username required']);
        exit;
    }

    
    $userStmt = $pdo->prepare("SELECT id FROM users WHERE username = ?");
    $userStmt->execute([$username]);
    $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    if (!$user) {
        http_response_code(404);
        echo json_encode(['error' => 'User not found']);
        exit;
    }

    
    $sql = "
        SELECT tn.*, 
               u.username AS sender_username, 
               t.title AS thread_title,
               t.visibility,
               t.invite_code
        FROM threads_notifications tn 
        LEFT JOIN users u ON tn.sender_id = u.id 
        LEFT JOIN threads t ON tn.thread_id = t.thread_id 
        WHERE tn.user_id = ?
    ";
    $params = [$user['id']];

    if ($isRead !== null) {
        $sql .= " AND tn.is_read = ?";
        $params[] = (int)$isRead;
    }

    $sql .= " ORDER BY tn.created_at DESC";

    // Execute query
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $notifications = $stmt->fetchAll(PDO::FETCH_ASSOC);


    echo json_encode($notifications);

} catch (Exception $e) {
    error_log("Error in get_notifications.php: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Internal Server Error']);
}
?>