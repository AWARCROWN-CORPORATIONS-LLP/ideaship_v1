<?php
// -------------------------------------
// GLOBAL PHP TIMEZONE (IMPORTANT)
// -------------------------------------
date_default_timezone_set("Asia/Kolkata");

// -------------------------------------
// DATABASE CONFIGURATION
// -------------------------------------
$host = 'localhost';
$dbname = 'app_auth';
$username = 'awarcrownadmins';
$password = 'Awarcrown@0523';

try {
    // Create PDO connection
    $pdo = new PDO(
        "mysql:host=$host;dbname=$dbname;charset=utf8",
        $username,
        $password,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
        ]
    );

    // -----------------------------------------------------
    // 🔥 FIX MYSQL TIMEZONE FOR THIS CONNECTION ONLY
    // (Works even without SUPER privileges)
    // -----------------------------------------------------
    $pdo->exec("SET time_zone = '+05:30'");

} catch (PDOException $e) {
    die("Database connection failed: " . $e->getMessage());
}
?>
