<?php
/**
 * Secure Image Serving Script for Comment Images
 * ------------------------------------------------
 * - Prevents directory traversal
 * - Validates MIME types
 * - Logs errors
 * - Sends safe, professional responses
 */

require_once 'config.php';

// ---------------------------------------
// 🔐 Error Logging Setup
// ---------------------------------------
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
error_reporting(E_ALL & ~E_DEPRECATED);

/**
 * Safe JSON error output + log
 */
function send_error($message, $status = 400) {
    http_response_code($status);
    error_log("[IMAGE_SERVE_ERROR] {$message}");
    echo json_encode(['error' => $message]);
    exit;
}

// ---------------------------------------
// 🔍 Validate & sanitize input
// ---------------------------------------
$filename = $_GET['file'] ?? '';

if (!$filename) {
    send_error("Missing 'file' parameter", 400);
}

// Prevent directory traversal like ../../etc/passwd
$filename = basename($filename);

// Must only allow safe characters (extra security)
if (!preg_match('/^[A-Za-z0-9._-]+$/', $filename)) {
    send_error("Invalid filename format", 400);
}

$filepath = __DIR__ . "/uploads/comments/" . $filename;

// ---------------------------------------
// 📁 Validate file existence
// ---------------------------------------
if (!file_exists($filepath)) {
    send_error("Requested image not found: $filename", 404);
}

// ---------------------------------------
// 🛡 Validate MIME type
// ---------------------------------------
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $filepath);
finfo_close($finfo);

$allowedMimes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp'
];

if (!in_array($mimeType, $allowedMimes)) {
    send_error("Blocked attempt to access non-image file ($mimeType)", 403);
}

// ---------------------------------------
// 📦 Send headers
// ---------------------------------------
$filesize = filesize($filepath);

header("Content-Type: {$mimeType}");
header("Content-Length: {$filesize}");
header("Cache-Control: public, max-age=31536000");
header("Expires: " . gmdate("D, d M Y H:i:s", time() + 31536000) . " GMT");

// ---------------------------------------
// 📤 Output image
// ---------------------------------------
if (@readfile($filepath) === false) {
    send_error("Failed to read image file", 500);
}

exit;
