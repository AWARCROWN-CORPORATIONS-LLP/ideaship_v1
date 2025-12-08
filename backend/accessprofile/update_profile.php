<?php
header('Content-Type: application/json');
require_once 'config.php';

header('Access-Control-Allow-Origin: *');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
    exit;
}

function clean($v) {
    return trim($v);
}

try {

    error_log("🔍 update_profile.php request received");

    // --------------------------
    // READ INPUT
    // --------------------------
    $data = $_POST;
    error_log("📩 Incoming POST: " . json_encode($data));

    if (empty($data['username'])) {
        error_log("❌ ERROR: Username missing");
        echo json_encode(['success' => false, 'message' => 'Username is required']);
        exit;
    }

    $username = clean($data['username']);
    error_log("👤 Updating profile for username: $username");

    // --------------------------
    // GET USER + ROLE
    // --------------------------
    $stmt = $pdo->prepare("
        SELECT u.id, ur.role 
        FROM users u
        LEFT JOIN user_role ur ON u.id = ur.user_id
        WHERE u.username = ?
    ");
    $stmt->execute([$username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    error_log("🔎 User Fetch Result: " . json_encode($user));

    if (!$user) {
        error_log("❌ ERROR: User not found");
        echo json_encode(['success' => false, 'message' => 'User not found']);
        exit;
    }

    $user_id   = $user['id'];
    $role_type = $user['role'];

    error_log("📌 User Role: $role_type | User ID: $user_id");

    if (!$role_type) {
        error_log("❌ ERROR: User role missing in DB");
        echo json_encode(['success' => false, 'message' => 'User role missing']);
        exit;
    }

    // --------------------------
    // ALLOWED FIELDS
    // --------------------------
    $student_fields = [
        'full_name','dob','phone','address','nationality','institution','student_id',
        'academic_level','major','expected_passout_year','linkedin','portfolio',
        'skills_dev','interests','bio'
    ];

    $startup_fields = [
        'founders_names','startup_name','phone','address','industry',
        'team_size','linkedin','instagram','facebook',
        'founding_date','stage','highlights','funding_goals','mentorship_needs',
        'business_vision','business_reg_type','business_registration','founder_id',
        'gov_id_type','reference','additional_docs','supporting_docs',
        'email_verification','description'
    ];

    if ($role_type === "student") {
        $table = "student_profiles";
        $allowed = $student_fields;
    }
    else if ($role_type === "startup") {
        $table = "startup_profiles";
        $allowed = $startup_fields;
    }
    else {
        error_log("❌ ERROR: Invalid role '$role_type'");
        echo json_encode(['success' => false, 'message' => 'Invalid role']);
        exit;
    }

    error_log("📄 Updating Table: $table");

    // --------------------------
    // BUILD UPDATE QUERY
    // --------------------------
    $update_fields = [];
    $params = [":uid" => $user_id];

    foreach ($allowed as $field) {
        if (isset($data[$field])) {
            $value = clean($data[$field]);
            $update_fields[] = "$field = :$field";
            $params[":$field"] = $value;
            error_log("📝 FIELD SET: $field = '$value'");
        }
    }

    if (empty($update_fields)) {
        error_log("⚠ No valid fields provided — nothing to update.");
        echo json_encode(['success' => false, 'message' => 'No fields provided to update']);
        exit;
    }

    // --------------------------
    // EXECUTE UPDATE
    // --------------------------
    $sql = "UPDATE $table SET " . implode(", ", $update_fields) . ", updated_at = NOW() WHERE user_id = :uid";
    
    error_log("📌 FINAL SQL: $sql");
    error_log("📌 SQL PARAMS: " . json_encode($params));

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    error_log("✅ Profile updated successfully for user_id: $user_id");

    echo json_encode(['success' => true, 'message' => 'Profile updated successfully']);

} catch (Exception $e) {

    error_log("❌ EXCEPTION in update_profile.php: " . $e->getMessage());
    error_log("❌ TRACE: " . $e->getTraceAsString());

    echo json_encode(['success' => false, 'message' => 'Server error']);
}
?>
