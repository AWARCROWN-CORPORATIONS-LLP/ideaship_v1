<?php
require_once 'config.php';
header('Content-Type: application/json');

$input = json_decode(file_get_contents('php://input'), true);
$username = $input['username'] ?? null;
$token = $input['token'] ?? null;

if (!$username || !$token) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing username or token']);
    exit;
}

$stmt = $pdo->prepare("UPDATE users SET fcm_token = ? WHERE username = ?");
$stmt->execute([$token, $username]);

echo json_encode(['success' => true]);
?>