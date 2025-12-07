<?php
session_start();
require_once 'config.php';

try {
    // ✅ Initialize PDO using variables from config.php
    $dsn = "mysql:host=$host;dbname=$dbname;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]);

    // ✅ Start transaction
    $pdo->beginTransaction();

    // User session or POST data
    $userId = $_POST['id'] ?? $_SESSION['user_id'] ?? null;
    $username = $_POST['username'] ?? $_SESSION['username'] ?? null;
    $email = $_POST['email'] ?? $_SESSION['email'] ?? null;
    $roleType = $_POST['role_type'] ?? 'startup';

    if (!$userId || !$username || !$email) {
        $pdo->rollBack();
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'User not logged in']);
        exit;
    }

    // Collect and sanitize form data
    $data = [
        'user_id' => $userId,
        'username' => $username,
        'email' => $email,
        'founders_names' => trim($_POST['founders_names'] ?? ''),
        'startup_name' => trim($_POST['startup_name'] ?? ''),
        'phone' => trim($_POST['phone'] ?? ''),
        'address' => trim($_POST['address'] ?? ''),
        'industry' => trim($_POST['industry'] ?? ''),
        'linkedin' => trim($_POST['linkedin'] ?? ''),
        'instagram' => trim($_POST['instagram'] ?? ''),
        'facebook' => trim($_POST['facebook'] ?? ''),
        'founding_date' => $_POST['founding_date'] ?? '',
        'stage' => trim($_POST['stage'] ?? ''),
        'team_size' => $_POST['team_size'] ?? null,
        'highlights' => trim($_POST['highlights'] ?? ''),
        'additional_docs' => trim($_POST['additional_docs'] ?? ''),
        'funding_goals' => trim($_POST['funding_goals'] ?? ''),
        'mentorship_needs' => trim($_POST['mentorship_needs'] ?? ''),
        'business_vision' => trim($_POST['business_vision'] ?? ''),
        'business_reg_type' => trim($_POST['business_reg_type'] ?? ''),
        'business_registration' => trim($_POST['business_registration'] ?? ''),
        'founder_id' => trim($_POST['founder_id'] ?? ''),
        'gov_id_type' => trim($_POST['gov_id_type'] ?? ''),
        'reference' => trim($_POST['reference'] ?? ''),
        'supporting_docs' => trim($_POST['supporting_docs'] ?? ''),
        'email_verification' => $_POST['email_verification'] ?? 'verified',
        'role_type' => $roleType,
    ];

    // ✅ Required fields validation
    $requiredFields = [
        'founders_names', 'startup_name', 'phone', 'address', 'industry', 'founding_date',
        'stage', 'team_size', 'highlights', 'funding_goals', 'mentorship_needs',
        'business_vision', 'business_reg_type', 'founder_id', 'gov_id_type', 'reference'
    ];

    foreach ($requiredFields as $field) {
        if (empty($data[$field])) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => ucfirst(str_replace('_', ' ', $field)) . ' is required']);
            exit;
        }
    }

    // ✅ Validate Business Registration
    if ($data['business_reg_type'] !== 'Not Registered') {
        if (empty($data['business_registration'])) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Business registration number is required']);
            exit;
        }
        if ($data['business_reg_type'] === 'LLP' && !preg_match('/^[A-Z]{3}-\d{4}$/', $data['business_registration'])) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Invalid LLP ID format (e.g., AAB-1234)']);
            exit;
        }
        if (($data['business_reg_type'] === 'Private Limited' || $data['business_reg_type'] === 'Public Limited')
            && !preg_match('/^U\d{5}[A-Z]{2}\d{4}PTC\d{6}$/', $data['business_registration'])) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Invalid CIN format (e.g., U72900MH2023PTC123456)']);
            exit;
        }
        if ($data['business_reg_type'] === 'Other' && strlen($data['business_registration']) < 5) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Other registration ID must be at least 5 characters']);
            exit;
        }
    }

    // ✅ Basic format validations
    if (!empty($data['phone']) && !preg_match('/^\+?[\d\s\-\(\)]{10,}$/', $data['phone'])) {
        $pdo->rollBack();
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid phone number format']);
        exit;
    }

    if (!empty($data['email']) && !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
        $pdo->rollBack();
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid email format']);
        exit;
    }

    if (!empty($data['linkedin']) && !preg_match('/^https?:\/\/(www\.)?linkedin\.com\/.*$/', $data['linkedin'])) {
        $pdo->rollBack();
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid LinkedIn URL']);
        exit;
    }

    if (!empty($data['instagram']) && !preg_match('/^https?:\/\/(www\.)?instagram\.com\/.*$/', $data['instagram'])) {
        $pdo->rollBack();
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid Instagram URL']);
        exit;
    }

    if (!empty($data['facebook']) && !preg_match('/^https?:\/\/(www\.)?facebook\.com\/.*$/', $data['facebook'])) {
        $pdo->rollBack();
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Invalid Facebook URL']);
        exit;
    }

    // ✅ Check existing startup profile
    $checkStmt = $pdo->prepare("SELECT user_id FROM startup_profiles WHERE user_id = :user_id");
    $checkStmt->execute(['user_id' => $userId]);
    if ($checkStmt->fetch()) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['success' => false, 'message' => 'Profile already exists for this user']);
        exit;
    }

    // ✅ Handle logo upload
    if (isset($_FILES['logo']) && $_FILES['logo']['error'] === UPLOAD_ERR_OK) {
        $allowedTypes = ['image/jpeg', 'image/png'];
        $maxSize = 5 * 1024 * 1024; // 5 MB
        $fileType = $_FILES['logo']['type'];
        $fileSize = $_FILES['logo']['size'];

        if (!in_array($fileType, $allowedTypes)) {
            throw new Exception('Profile picture must be JPEG or PNG');
        }
        if ($fileSize > $maxSize) {
            throw new Exception('Profile picture size exceeds 5MB');
        }

        $uploadDir = '../feed/uploads/';
        if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);

        $fileName = $userId . '_' . time() . '_' . basename($_FILES['logo']['name']);
        $filePath = $uploadDir . $fileName;
        move_uploaded_file($_FILES['logo']['tmp_name'], $filePath);

        // Update user profile picture
        $updateStmt = $pdo->prepare("UPDATE users SET profile_picture = :pic WHERE id = :uid");
        $updateStmt->execute(['pic' => '../feed/uploads/' . $fileName, 'uid' => $userId]);
    }

    // ✅ Insert into startup_profiles
    $stmt = $pdo->prepare("
        INSERT INTO startup_profiles (
            user_id, username, email, founders_names, startup_name, phone, address, industry,
            linkedin, instagram, facebook, founding_date, stage, team_size, highlights,
            additional_docs, funding_goals, mentorship_needs, business_vision, business_reg_type,
            business_registration, founder_id, gov_id_type, reference, supporting_docs,
            email_verification, role_type
        ) VALUES (
            :user_id, :username, :email, :founders_names, :startup_name, :phone, :address, :industry,
            :linkedin, :instagram, :facebook, :founding_date, :stage, :team_size, :highlights,
            :additional_docs, :funding_goals, :mentorship_needs, :business_vision, :business_reg_type,
            :business_registration, :founder_id, :gov_id_type, :reference, :supporting_docs,
            :email_verification, :role_type
        )
    ");
    $stmt->execute($data);

    // ✅ Insert into user_role
    $roleStmt = $pdo->prepare("INSERT INTO user_role (profile_id, user_id, role) VALUES (:pid, :uid, :role)");
    $roleStmt->execute([
        'pid' => $userId,
        'uid' => $userId,
        'role' => $roleType
    ]);

    // ✅ Commit transaction
    $pdo->commit();

    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'Startup profile saved successfully']);

} catch (PDOException $e) {
    if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack();
    error_log("Database error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database error occurred']);
} catch (Exception $e) {
    if (isset($pdo) && $pdo->inTransaction()) $pdo->rollBack();
    error_log("General error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
