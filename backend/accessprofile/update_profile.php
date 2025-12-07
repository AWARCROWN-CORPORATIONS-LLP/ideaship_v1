<?php
header('Content-Type: application/json');
require_once 'config.php';

header('Access-Control-Allow-Origin: *');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    exit;
}

function sanitize($data) {
    return trim($data);
}

try {
    $data = $_POST;
    if (empty($data['username'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Username is required']);
        exit;
    }

    $username = sanitize($data['username']);
    $stmt = $pdo->prepare("
        SELECT u.id, ur.role_type
        FROM users u
        LEFT JOIN user_role ur ON u.id = ur.user_id
        WHERE u.username = :username
    ");
    $stmt->execute([':username' => $username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'User not found']);
        exit;
    }

    $user_id = $user['id'];
    $role_type = $user['role_type'] ?? null;

    $allowed_fields = [
        'Student/Professional' => [
            'full_name', 'dob', 'phone', 'address', 'nationality', 'institution', 'student_id', 'job_title',
            'company', 'linkedin', 'academic_level', 'major', 'gpa', 'coursework', 'extracurricular',
            'work_exp', 'skills', 'projects', 'certifications', 'portfolio', 'career_goals',
            'industry_pref', 'job_type', 'location_pref', 'work_env', 'availability', 'skills_dev',
            'interests', 'gov_id', 'student_id_card', 'email_verification', 'reference',
            'bg_check_consent', 'employee_id', 'education_status', 'expected_passout_year',
            'job_status', 'gov_id_type'
        ],
        'Company/HR' => [
            'company_name', 'contact_person_name', 'contact_designation', 'contact_email',
            'contact_phone', 'company_address', 'industry', 'company_size', 'website',
            'linkedin_profile', 'candidate_preferences', 'diversity_goals', 'location_preferences',
            'budget', 'company_culture', 'preferred_talent_sources', 'training_programs',
            'business_registration', 'authorized_signatory', 'ein', 'reference_contact',
            'website_domain_verification', 'email_verification', 'bg_check_consent'
        ]
    ];

    $update_fields = [];
    $params = [':uid' => $user_id];
    foreach ($allowed_fields[$role_type] as $field) {
        if (!empty(trim($data[$field] ?? ''))) {
            $update_fields[] = "$field = :$field";
            $params[":$field"] = sanitize($data[$field]);
        }
    }

    if (empty($update_fields)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'No valid fields provided for update']);
        exit;
    }

    $table = $role_type === 'Student/Professional' ? 'students_profile' : 'company_profiles';
    $sql = "UPDATE $table SET " . implode(', ', $update_fields) . ", updated_at = NOW() WHERE user_id = :uid";
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    echo json_encode(['success' => true, 'message' => 'Profile updated successfully']);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Server error']);
    error_log("Profile update exception: " . $e->getMessage());
}
?>