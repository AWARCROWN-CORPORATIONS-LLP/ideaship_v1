<?php
/**
 * Secure Image Serving Script for Comment Images
 * 
 * This script serves comment images securely, preventing direct access
 * and ensuring proper file validation.
 */

require_once 'config.php';

// Get image filename from query parameter
$filename = $_GET['file'] ?? '';

if (empty($filename)) {
    http_response_code(400);
    die('Invalid request');
}

// Sanitize filename to prevent directory traversal
$filename = basename($filename);
$filepath = __DIR__ . '/uploads/comments/' . $filename;

// Validate file exists
if (!file_exists($filepath)) {
    http_response_code(404);
    die('Image not found');
}

// Validate file is actually an image
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $filepath);
finfo_close($finfo);

$allowedMimes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
if (!in_array($mimeType, $allowedMimes)) {
    http_response_code(403);
    die('Invalid file type');
}

// Get file size
$filesize = filesize($filepath);

// Set appropriate headers
header('Content-Type: ' . $mimeType);
header('Content-Length: ' . $filesize);
header('Cache-Control: public, max-age=31536000'); // Cache for 1 year
header('Expires: ' . gmdate('D, d M Y H:i:s', time() + 31536000) . ' GMT');

// Output file
readfile($filepath);
exit;

