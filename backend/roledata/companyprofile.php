<?php
header('Content-Type: application/json');
require_once 'config.php'; // must return $pdo (PDO instance)

// Handle CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    exit;
}
header('Access-Control-Allow-Origin: *');

// Handle company role submission
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $_SERVER['REQUEST_URI'] === '/roledata/companyprofile') {
    $data = $_POST; // Flutter sends form-data via POST

    // Required fields validation
    $required_fields = [
        'username', 'company_name', 'contact_person_name', 'contact_designation',
        'contact_email', 'contact_phone', 'company_address', 'industry',
        'company_size', 'website', 'candidate_preferences', 'diversity_goals',
        'location_preferences', 'budget', 'company_culture', 'preferred_talent_sources',
        'training_programs', 'business_registration', 'authorized_signatory',
        'ein', 'reference_contact', 'website_domain_verification', 'bg_check_consent'
    ];

    foreach ($required_fields as $field) {
        if (empty(trim($data[$field] ?? ''))) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => "Missing or empty required field: $field"]);
            exit;
        }
    }

    // Validations
    if (!filter_var($data['contact_email'], FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid contact email format']);
        exit;
    }

    if (!preg_match('/^\+?[\d\s\-\(\)]{10,}$/', $data['contact_phone'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid contact phone format']);
        exit;
    }

    if (!preg_match('/^(https?:\/\/)?[\w.-]+\.[a-z]{2,}$/', $data['website'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid website URL']);
        exit;
    }

    if ($data['bg_check_consent'] !== 'true') {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Background check consent is required']);
        exit;
    }

    // --- Fetch user_id from users table ---
    $stmt = $pdo->prepare("SELECT id FROM users WHERE username = :username AND is_active = 1");
    $stmt->execute([':username' => $data['username']]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'User not found']);
        exit;
    }

    $user_id = $user['id'];

   
    $stmt = $pdo->prepare("SELECT id FROM company_profiles WHERE user_id = :user_id AND is_active = 1");
    $stmt->execute([':user_id' => $user_id]);
    if ($stmt->fetch()) {
        http_response_code(409);
        echo json_encode(['success' => false, 'message' => 'Company profile already exists for this user']);
        exit;
    }

    // Prepare data
    $created_at = date('Y-m-d H:i:s');
    $fields = [
        'user_id' => $user_id,
        'company_name' => $data['company_name'],
        'contact_person_name' => $data['contact_person_name'],
        'contact_designation' => $data['contact_designation'],
        'contact_email' => $data['contact_email'],
        'contact_phone' => $data['contact_phone'],
        'company_address' => $data['company_address'],
        'industry' => $data['industry'],
        'company_size' => $data['company_size'],
        'website' => $data['website'],
        'linkedin_profile' => $data['linkedin_profile'] ?? '',
        'candidate_preferences' => $data['candidate_preferences'],
        'diversity_goals' => $data['diversity_goals'],
        'location_preferences' => $data['location_preferences'],
        'budget' => $data['budget'],
        'company_culture' => $data['company_culture'],
        'preferred_talent_sources' => $data['preferred_talent_sources'],
        'training_programs' => $data['training_programs'],
        'business_registration' => $data['business_registration'],
        'authorized_signatory' => $data['authorized_signatory'],
        'ein' => $data['ein'],
        'reference_contact' => $data['reference_contact'],
        'website_domain_verification' => $data['website_domain_verification'],
        'email_verification' => $data['email_verification'] ?? '',
        'role_type' => $data['role_type'] ?? 'company',
        'created_at' => $created_at,
        'is_active' => 1
    ];

    // Build query dynamically
    $columns = implode(', ', array_keys($fields));
    $placeholders = ':' . implode(', :', array_keys($fields));

    $stmt = $pdo->prepare("
        INSERT INTO company_profiles ($columns)
        VALUES ($placeholders)
    ");

    try {
        $pdo->beginTransaction();

        $stmt->execute($fields);

        // Update user role
        $update = $pdo->prepare("UPDATE users SET role = 'company' WHERE id = :id");
        $update->execute([':id' => $user_id]);

        $pdo->commit();

        echo json_encode([
            'success' => true,
            'message' => 'Company profile successfully registered',
            'data' => ['user_id' => $user_id]
        ]);
    } catch (Exception $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Failed to save profile', 'error' => $e->getMessage()]);
    }
}
?>
