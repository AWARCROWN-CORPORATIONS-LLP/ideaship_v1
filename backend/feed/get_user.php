
<?php
header('Content-Type: application/json');
require_once 'config.php';

$username = trim($_GET['username'] ?? '');
if (empty($username)) {
    echo json_encode(['error' => 'Username is required']);
    exit;
}

try {
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ? AND is_active = 1 LIMIT 1");
    $stmt->execute([$username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($user) {
        echo json_encode(['user_id' => (int)$user['id']]);
    } else {
        echo json_encode(['error' => 'User not found']);
    }
} catch (Exception $e) {
    error_log("get_user.php error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error']);
}
?>
