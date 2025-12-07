
<?php
header('Content-Type: application/json');
require_once 'config.php';

header('Access-Control-Allow-Origin: *');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    exit;
}

function sanitize($data) { return trim($data); }

try {
    $username = '';
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true) ?? [];
        $username = $input['username'] ?? '';
    } else {
        $username = $_GET['username'] ?? '';
    }

    if (empty($username)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Username is required']);
        exit;
    }

    $username = sanitize($username);
    $stmt = $pdo->prepare("
        SELECT u.id, u.profile_picture, ur.role 
        FROM users u 
        LEFT JOIN user_role ur ON u.id = ur.user_id 
        WHERE u.username = ? AND u.is_active = 1
    ");
    $stmt->execute([$username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'User not found']);
        exit;
    }

    $profile = [
        'role' => $user['role'],
        'profile_picture' => $user['profile_picture']
    ];

    if ($user['role'] === 'student') {
        $stmt = $pdo->prepare("SELECT * FROM student_profiles WHERE user_id = ?");
        $stmt->execute([$user['id']]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($data) $profile = array_merge($profile, $data);
    } elseif ($user['role'] === 'company') {
        $stmt = $pdo->prepare("SELECT * FROM company_profiles WHERE user_id = ?");
        $stmt->execute([$user['id']]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($data) $profile = array_merge($profile, $data);
    }

    echo json_encode(['success' => true, 'data' => $profile]);

} catch (Exception $e) {
    error_log("userprofile_info error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error']);
}
?>
