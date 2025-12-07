<?php
session_start();

require_once 'config.php';



function sendResponse($statusCode, $success, $message, $extra = []) {
    http_response_code($statusCode);
    echo json_encode(array_merge([
        'success' => $success,
        'message' => $message
    ], $extra));
    exit;
}

try {
    // === DB Connection ===
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]);

    // === Validate User ID ===
   $userId = $_POST['id'] ?? $_GET['id'] ?? null;


    if (!$userId || !ctype_digit($userId)) {
        sendResponse(400, false, 'Valid User ID is required');
    }

    // === Check if user exists in user_role and fetch role ===
    $checkStmt = $pdo->prepare("SELECT user_id, role FROM user_role WHERE user_id = :user_id LIMIT 1");
    $checkStmt->execute(['user_id' => $userId]);
    $result = $checkStmt->fetch();

    $completed = $result ? true : false;
    $role = $result ? $result['role'] : null;

    sendResponse(200, true, 'Request successful', [
        'completed' => $completed,
        'user_id'   => $userId,
        'role'      => $role
    ]);

} catch (PDOException $e) {
    error_log("[DB ERROR] " . $e->getMessage() . " in " . $e->getFile() . " line " . $e->getLine());
    sendResponse(500, false, 'Database error occurred');
} catch (Exception $e) {
    error_log("[GENERAL ERROR] " . $e->getMessage() . " in " . $e->getFile() . " line " . $e->getLine());
    sendResponse(500, false, 'An unexpected error occurred');
}
?>