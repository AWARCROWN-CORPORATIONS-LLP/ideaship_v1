<?php
session_start();

require_once 'config.php';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->beginTransaction();

    // Get user data from POST (from form) or session as fallback
    $userId = $_POST['id'] ?? $_SESSION['user_id'] ?? null;
    $username = $_POST['username'] ?? $_SESSION['username'] ?? null;
    $email = $_POST['email'] ?? $_SESSION['email'] ?? null;
    $roleType = 'student'; // Fixed to student

    if (!$userId || !$username || !$email) {
        $pdo->rollBack();
        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'User not logged in']);
        exit;
    }

    // Get form data
    $data = [
        'user_id' => $userId,
        'username' => $username,
        'email' => $email,
        'full_name' => trim($_POST['full_name'] ?? ''),
        'dob' => $_POST['dob'] ?? '',
        'phone' => trim($_POST['phone'] ?? ''),
        'address' => trim($_POST['address'] ?? ''),
        'nationality' => trim($_POST['nationality'] ?? ''),
        'institution' => trim($_POST['institution'] ?? ''),
        'student_id' => trim($_POST['student_id'] ?? ''),
        'linkedin' => trim($_POST['linkedin'] ?? ''),
        'academic_level' => trim($_POST['academic_level'] ?? ''),
        'major' => trim($_POST['major'] ?? ''),
        'portfolio' => trim($_POST['portfolio'] ?? ''),
        'skills_dev' => trim($_POST['skills_dev'] ?? ''),
        'interests' => trim($_POST['interests'] ?? ''),
        'expected_passout_year' => trim($_POST['expected_passout_year'] ?? ''),
        'email_verification' => $_POST['email_verification'] ?? 'verified',
        'role_type' => $roleType,
    ];

    // Validate required fields for student
    $requiredFields = ['full_name', 'dob', 'phone', 'address', 'nationality', 'institution', 'student_id', 'academic_level', 'major', 'skills_dev', 'interests', 'expected_passout_year'];

    foreach ($requiredFields as $field) {
        if (empty($data[$field])) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => ucfirst(str_replace('_', ' ', $field)) . ' is required']);
            exit;
        }
    }

    // Additional custom validations
    if (!empty($data['dob'])) {
        $dob = DateTime::createFromFormat('Y-m-d', $data['dob']);
        $age = (new DateTime())->diff($dob)->y;
        if ($age < 16 || $age > 100) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Age must be between 16 and 100 years']);
            exit;
        }
    }

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

    if (!empty($data['linkedin'])) {
        if (!preg_match('/^https?:\/\/(www\.)?linkedin\.com\/in\/.+$/', $data['linkedin'])) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Invalid LinkedIn URL']);
            exit;
        }
    }

    if (!empty($data['expected_passout_year'])) {
        $year = (int)$data['expected_passout_year'];
        $currentYear = (int)date('Y');
        if ($year < $currentYear || $year > $currentYear + 10) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Expected passout year must be between current year and +10 years']);
            exit;
        }
    }

    if (!empty($data['portfolio'])) {
        if (!preg_match('/^(https?://)?[\w.-]+\.[a-z]{2,}$/', $data['portfolio'])) {
            $pdo->rollBack();
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Enter valid URL']);
            exit;
        }
    }

    // Check if profile already exists for user
    $checkStmt = $pdo->prepare("SELECT user_id FROM student_profiles WHERE user_id = :user_id");
    $checkStmt->execute(['user_id' => $userId]);
    if ($checkStmt->fetch()) {
        $pdo->rollBack();
        http_response_code(409);
        echo json_encode(['success' => false, 'message' => 'Profile already exists for this user']);
        exit;
    }

    // Insert into database
    $stmt = $pdo->prepare("
        INSERT INTO student_profiles (
            user_id, username, email, full_name, dob, phone, address, nationality, institution, 
            student_id, linkedin, academic_level, major, portfolio, 
            skills_dev, interests, expected_passout_year, 
            email_verification, role_type
        ) VALUES (
            :user_id, :username, :email, :full_name, :dob, :phone, :address, :nationality, :institution, 
            :student_id, :linkedin, :academic_level, :major, :portfolio, 
            :skills_dev, :interests, :expected_passout_year, 
            :email_verification, :role_type
        )
    ");
    $stmt->execute($data);

    // Insert into user_role table
    $roleData = [
        'profile_id' => $userId,
        'user_id' => $userId,
        'role' => $roleType
    ];
    $roleStmt = $pdo->prepare("
        INSERT INTO user_role (profile_id, user_id, role) 
        VALUES (:profile_id, :user_id, :role)
    ");
    $roleStmt->execute($roleData);

    $pdo->commit();

    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'Profile saved successfully']);

} catch (PDOException $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("Database error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database error occurred']);
} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("General error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'An error occurred']);
}
?>