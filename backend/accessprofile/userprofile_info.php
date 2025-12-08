<?php
header('Content-Type: application/json');
require_once 'config.php';

// CORS
header('Access-Control-Allow-Origin: *');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    exit;
}

function sanitize($data) { 
    return trim(htmlspecialchars($data)); 
}

try {
    // -----------------------------------------
    // READ INPUT (POST JSON or GET)
    // -----------------------------------------
    $username = '';

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true) ?? [];
        $username = $input['username'] ?? '';
    } else {
        $username = $_GET['username'] ?? '';
    }

    if (!$username) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Username is required']);
        exit;
    }

    $username = sanitize($username);

    // -----------------------------------------
    // FETCH BASE USER + ROLE
    // -----------------------------------------
    $stmt = $pdo->prepare("
        SELECT 
            u.id AS user_id,
            u.username,
            u.email,
            u.profile_picture,
            ur.role
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

    // Base response
    $profile = [
        'user_id'         => $user['user_id'],
        'username'        => $user['username'],
        'email'           => $user['email'],
        'role'            => $user['role'],
        'profile_picture' => $user['profile_picture']
    ];

    // -----------------------------------------
    // STUDENT PROFILE
    // -----------------------------------------
    if ($user['role'] === 'student') {
        $stmt = $pdo->prepare("SELECT * FROM student_profiles WHERE user_id = ?");
        $stmt->execute([$user['user_id']]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($data) {
            // Remove duplicate user_id field to avoid conflict
            unset($data['user_id']);
            $profile = array_merge($profile, $data);
        }
    }

    // -----------------------------------------
    // STARTUP PROFILE (Updated Schema)
    // -----------------------------------------
    elseif ($user['role'] === 'startup') {

        $stmt = $pdo->prepare("SELECT * FROM startup_profiles WHERE user_id = ?");
        $stmt->execute([$user['user_id']]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($data) {
            unset($data['user_id']);

            // Normalize field names for frontend
            $normalized = [
                'startup_id'              => $data['startup_id'],
                'founders_names'          => $data['founders_names'],
                'startup_name'            => $data['startup_name'],
                'phone'                   => $data['phone'],
                'address'                 => $data['address'],
                'industry'                => $data['industry'],
                'linkedin'                => $data['linkedin'],
                'instagram'               => $data['instagram'],
                'facebook'                => $data['facebook'],
                'founding_date'           => $data['founding_date'],
                'stage'                   => $data['stage'],
                'team_size'               => $data['team_size'],
                'highlights'              => $data['highlights'],
                'additional_docs'         => $data['additional_docs'],
                'funding_goals'           => $data['funding_goals'],
                'mentorship_needs'        => $data['mentorship_needs'],
                'business_vision'         => $data['business_vision'],
                'business_reg_type'       => $data['business_reg_type'],
                'business_registration'   => $data['business_registration'],
                'founder_id'              => $data['founder_id'],
                'gov_id_type'             => $data['gov_id_type'],
                'reference'               => $data['reference'],
                'supporting_docs'         => $data['supporting_docs'],
                'email_verification'      => $data['email_verification'],
                'role_type'               => $data['role_type'],
                'created_at'              => $data['created_at'],
                'updated_at'              => $data['updated_at'],
                'followers_count'         => $data['followers_count'],
                'likes_count'             => $data['likes_count'],
                'favorites_count'         => $data['favorites_count'],
                'share_count'             => $data['share_count']
            ];

            $profile = array_merge($profile, $normalized);
        }
    }

    // -----------------------------------------
    // SUCCESS RESPONSE
    // -----------------------------------------
    echo json_encode([
        'success' => true,
        'data'    => $profile
    ]);

} catch (Exception $e) {
    error_log("userprofile_info.php ERROR: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error'
    ]);
}
?>
