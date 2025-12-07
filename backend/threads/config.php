<?php
require '/home/v6gkv3hx0rj5/vendor/autoload.php';

use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

// Database Configuration
$host = 'localhost';
$dbname = 'app_auth';
$username = 'awarcrownadmins';
$password = 'Awarcrown@0523';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die("Database connection failed: " . $e->getMessage());
}

// ✅ Correct path to Firebase service account JSON (outside public_html)
$serviceAccountPath = '/home/v6gkv3hx0rj5/ideashipthreads-notifications-firebase-adminsdk-fbsvc-1ad59db836.json';

// Verify file existence
if (!file_exists($serviceAccountPath)) {
    die("Service account file not found at: $serviceAccountPath");
}

try {
    $factory = (new Factory)->withServiceAccount($serviceAccountPath);
    $messaging = $factory->createMessaging();
} catch (Exception $e) {
    die("Firebase initialization failed: " . $e->getMessage());
}

function sendFCMNotification($pdo, $userId, $title, $body, $data = []) {
    global $messaging;

    try {
        $stmt = $pdo->prepare("SELECT fcm_token FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        $token = $stmt->fetchColumn();

        if (!$token) {
            return ['status' => 'error', 'message' => 'User has no FCM token'];
        }

        $notification = Notification::create($title, $body);
        $message = CloudMessage::withTarget('token', $token)
            ->withNotification($notification)
            ->withData($data);  // Ensure data payload is always included for navigation handling

        $messaging->send($message);

        return ['status' => 'success', 'message' => 'Notification sent'];
    } catch (Exception $e) {
        return ['status' => 'error', 'message' => $e->getMessage()];
    }
}
?>