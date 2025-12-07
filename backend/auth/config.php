<?php
$host = 'localhost';
$dbname = 'app_auth';
$username = 'awarcrownadmins';
$password = 'Awarcrown@0523';
$jwtSecret = 'AwarcrownSuperSecret2025'; 
try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    logError("Database connection failed: " . $e->getMessage());
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        header('Content-Type: text/html; charset=utf-8');
        outputErrorPage('Database connection failed');
    } else {
        header('Content-Type: application/json; charset=utf-8');
        sendErrorResponse(500, 'Database connection failed');
    }
    exit;
}
?>