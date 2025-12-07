<?php
// share_startup.php - Generate share link for startup
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['status' => 'error', 'message' => 'Invalid request method']);
    exit;
}

$input = file_get_contents('php://input');
$parsedInput = [];
parse_str($input, $parsedInput);

$startup_id = isset($parsedInput['startup_id']) ? intval($parsedInput['startup_id']) : 0;
$user_id    = isset($parsedInput['user_id']) ? intval($parsedInput['user_id']) : 0;

if ($startup_id <= 0 || $user_id <= 0) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid startup_id or user_id']);
    exit;
}

// Check if startup exists
$check = $pdo->prepare("SELECT startup_id FROM startup_profiles WHERE startup_id = ?");
$check->execute([$startup_id]);
if (!$check->fetch()) {
    echo json_encode(['status' => 'error', 'message' => 'Startup not found']);
    exit;
}

// Prevent duplicate share for the same user & startup
$stmt = $pdo->prepare("SELECT token FROM startup_shares WHERE startup_id = ? AND user_id = ?");
$stmt->execute([$startup_id, $user_id]);
$existing = $stmt->fetch(PDO::FETCH_ASSOC);

if ($existing) {
    $share_url = 'https://share.awarcrown.com/startup/' . $existing['token'];

    echo json_encode([
        'status' => 'success',
        'message' => 'Startup already shared',
        'share_url' => $share_url
    ]);
    exit;
}

// Generate a unique secure token
$token = bin2hex(random_bytes(16));

try {
    // Insert new share record
    $stmt = $pdo->prepare("
        INSERT INTO startup_shares (startup_id, user_id, token, created_at)
        VALUES (?, ?, ?, NOW())
    ");
    $stmt->execute([$startup_id, $user_id, $token]);

    // Update share count
    $stmt = $pdo->prepare("
        UPDATE startup_profiles 
        SET share_count = share_count + 1 
        WHERE startup_id = ?
    ");
    $stmt->execute([$startup_id]);

    // Build share URL
    $share_url = 'https://share.awarcrown.com/startup/' . $token;

    echo json_encode([
        'status' => 'success',
        'message' => 'Startup shared successfully',
        'share_url' => $share_url
    ]);

} catch (PDOException $e) {
    error_log("SHARE_STARTUP_ERROR: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Failed to share startup']);
}
?>
