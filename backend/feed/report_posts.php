<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'config.php'; // must define $pdo (PDO instance)

// Generate unique request ID for log tracing
$request_id = uniqid('report_', true);
error_log("[$request_id] Incoming report request received.");

// Only allow POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    error_log("[$request_id] Invalid request method: " . $_SERVER['REQUEST_METHOD']);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

try {
    // --- STEP 1: Read and detect input format ---
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    $raw_input = file_get_contents('php://input');
    $input = [];

    if (stripos($contentType, 'application/json') !== false) {
        $input = json_decode($raw_input, true) ?: [];
        error_log("[$request_id] Received JSON input: $raw_input");
    } elseif (!empty($_POST)) {
        $input = $_POST;
        error_log("[$request_id] Received FORM input: " . http_build_query($_POST));
    } else {
        parse_str($raw_input, $input); // handle raw form-encoded body
        error_log("[$request_id] Received RAW body input: $raw_input");
    }

    // --- STEP 2: Validate required fields ---
    if (
        !isset($input['post_id']) ||
        !isset($input['username']) ||
        !isset($input['reason'])
    ) {
        http_response_code(400);
        error_log("[$request_id] Missing required fields: " . json_encode($input));
        echo json_encode(['status' => 'error', 'message' => 'Missing required fields: post_id, username, reason']);
        exit;
    }

    $post_id = intval($input['post_id']);
    $username = trim($input['username']);
    $reason = trim($input['reason']);
    error_log("[$request_id] Parsed input => post_id: $post_id, username: $username, reason: $reason");

    if ($post_id <= 0 || empty($username) || empty($reason)) {
        http_response_code(400);
        error_log("[$request_id] Invalid input data detected.");
        echo json_encode(['status' => 'error', 'message' => 'Invalid input data']);
        exit;
    }

    // --- STEP 3: Ensure PDO connection ---
    if (!isset($pdo) || !$pdo instanceof PDO) {
        throw new Exception('Database connection ($pdo) is not defined in config.php');
    }

    // --- STEP 4: Check for duplicate reports (24-hour limit) ---
    $stmt = $pdo->prepare('
        SELECT id 
        FROM post_reports 
        WHERE post_id = ? 
          AND reporter_username = ? 
          AND created_at > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ');
    $stmt->execute([$post_id, $username]);
    if ($stmt->fetch()) {
        http_response_code(429);
        error_log("[$request_id] Duplicate report detected for user '$username' on post $post_id.");
        echo json_encode(['status' => 'error', 'message' => 'You have already reported this post recently. Please wait 24 hours.']);
        exit;
    }

    // --- STEP 5: Check if post exists ---
    $stmt = $pdo->prepare('SELECT post_id FROM posts WHERE post_id = ?');
    $stmt->execute([$post_id]);
    if (!$stmt->fetch()) {
        http_response_code(404);
        error_log("[$request_id] Post with ID $post_id not found.");
        echo json_encode(['status' => 'error', 'message' => 'Post not found']);
        exit;
    }

    // --- STEP 6: Insert report ---
    $stmt = $pdo->prepare('
        INSERT INTO post_reports (post_id, reporter_username, reason, status, created_at)
        VALUES (?, ?, ?, "pending", NOW())
    ');
    $stmt->execute([$post_id, $username, $reason]);
    error_log("[$request_id] Report inserted successfully for post $post_id by '$username'.");

    // Optional: notify admin
    // mail('admin@awarcrown.com', 'New Post Report', "Post ID: $post_id\nReporter: $username\nReason: $reason");

    // --- STEP 7: Respond success ---
    echo json_encode(['status' => 'success', 'message' => 'Report submitted successfully']);
    error_log("[$request_id] Report processed successfully.");

} catch (PDOException $e) {
    http_response_code(500);
    error_log("[$request_id] Database error: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Database error. Please try again later.']);
} catch (Exception $e) {
    http_response_code(500);
    error_log("[$request_id] General error: " . $e->getMessage());
    echo json_encode(['status' => 'error', 'message' => 'Server error. Please try again.']);
}
?>
