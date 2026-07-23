<?php
/**
 * Meta Lead Ads - Custom Licensing Server (cPanel Edition)
 * Upload this single file to your cPanel (e.g. https://yourdomain.com/license.php)
 *
 * It uses a lightweight SQLite database (which doesn't require MySQL setup!)
 * It will auto-create the database file `licenses.sqlite` in the same directory.
 */

// 1. Setup SQLite Database
$db_file = __DIR__ . '/licenses.sqlite';
$pdo = new PDO('sqlite:' . $db_file);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Create table if it doesn't exist
$pdo->exec("CREATE TABLE IF NOT EXISTS licenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    org_id TEXT UNIQUE,
    company_name TEXT,
    admin_email TEXT,
    license_key TEXT UNIQUE,
    status TEXT,
    expiration_date TEXT,
    max_pages INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)");

// 2. Handle Salesforce API Requests (JSON)
header('Content-Type: application/json');

$action = $_GET['action'] ?? '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    
    // Read JSON payload from Salesforce
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);

    // ==========================================
    // ACTION: REGISTER TRIAL (Called on first app open)
    // ==========================================
    if ($action === 'register') {
        $org_id = $data['org_id'] ?? '';
        $company_name = $data['company_name'] ?? 'Unknown';
        $admin_email = $data['admin_email'] ?? 'Unknown';

        if (empty($org_id)) {
            echo json_encode(['error' => 'Missing Org ID']);
            exit;
        }

        // Check if Org already exists
        $stmt = $pdo->prepare("SELECT * FROM licenses WHERE org_id = ?");
        $stmt->execute([$org_id]);
        $existing = $stmt->fetch();

        if ($existing) {
            // Already registered, return current status
            echo json_encode([
                'status' => $existing['status'],
                'expiry' => $existing['expiration_date'],
                'maxPages' => (int)$existing['max_pages']
            ]);
            exit;
        }

        // Create 14-day trial
        $trial_expiry = date('Y-m-d', strtotime('+14 days'));
        $temp_key = 'TRIAL-' . strtoupper(bin2hex(random_bytes(4)));

        $stmt = $pdo->prepare("INSERT INTO licenses (org_id, company_name, admin_email, license_key, status, expiration_date, max_pages) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $stmt->execute([$org_id, $company_name, $admin_email, $temp_key, 'Trial', $trial_expiry, 1]);

        echo json_encode([
            'status' => 'Trial',
            'expiry' => $trial_expiry,
            'maxPages' => 1
        ]);
        exit;
    }

    // ==========================================
    // ACTION: VALIDATE ACTIVATION KEY
    // ==========================================
    if ($action === 'validate') {
        $org_id = $data['org_id'] ?? '';
        $license_key = $data['license_key'] ?? '';

        if (empty($org_id) || empty($license_key)) {
            echo json_encode(['error' => 'Missing Org ID or License Key']);
            exit;
        }

        $stmt = $pdo->prepare("SELECT * FROM licenses WHERE license_key = ?");
        $stmt->execute([$license_key]);
        $license = $stmt->fetch();

        if (!$license) {
            echo json_encode(['status' => 'Invalid', 'error' => 'License Key not found.']);
            exit;
        }

        // Check if key is already assigned to a different Org
        if (!empty($license['org_id']) && $license['org_id'] !== $org_id) {
            echo json_encode(['status' => 'Invalid', 'error' => 'License Key is already registered to another Salesforce Org.']);
            exit;
        }

        // Update Org ID if it was a pre-generated blank key
        if (empty($license['org_id'])) {
            // Prevent UNIQUE constraint violation if Org already has a Trial record
            $checkStmt = $pdo->prepare("SELECT id FROM licenses WHERE org_id = ?");
            $checkStmt->execute([$org_id]);
            $existingOrg = $checkStmt->fetch();

            if ($existingOrg) {
                // Update the existing Trial row with the new key's limits
                $updStmt = $pdo->prepare("UPDATE licenses SET license_key = ?, status = 'Active', expiration_date = ?, max_pages = ? WHERE org_id = ?");
                $updStmt->execute([
                    $license['license_key'],
                    $license['expiration_date'],
                    $license['max_pages'],
                    $org_id
                ]);
                // Delete the original blank key row
                $delStmt = $pdo->prepare("DELETE FROM licenses WHERE id = ?");
                $delStmt->execute([$license['id']]);
            } else {
                // No existing trial found, just attach Org ID to this key
                $stmt = $pdo->prepare("UPDATE licenses SET org_id = ?, status = 'Active' WHERE id = ?");
                $stmt->execute([$org_id, $license['id']]);
            }
            $license['status'] = 'Active';
        }

        // Check Expiration
        if (strtotime($license['expiration_date']) < time()) {
            echo json_encode(['status' => 'Expired', 'expiry' => $license['expiration_date'], 'maxPages' => 0]);
            exit;
        }

        // Valid!
        echo json_encode([
            'status' => $license['status'],
            'expiry' => $license['expiration_date'],
            'maxPages' => (int)$license['max_pages']
        ]);
        exit;
    }
}

// 3. Simple Admin Dashboard (HTML/UI)
// If accessed via browser without an action, show the admin UI
header('Content-Type: text/html');
?>
<!DOCTYPE html>
<html>
<head>
    <meta name="robots" content="noindex, nofollow">
    <title>Meta Lead Ads - License Server</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; padding: 20px; background: #f4f6f9; }
        .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); max-width: 1000px; margin: 0 auto; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f8f9fa; }
        .badge-trial { background: #ffc107; color: #000; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
        .badge-active { background: #28a745; color: #fff; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
        .badge-expired { background: #dc3545; color: #fff; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
        .btn { background: #0070d2; color: white; border: none; padding: 10px 15px; border-radius: 4px; cursor: pointer; text-decoration: none; }
        .btn:hover { background: #005fb2; }
        input[type="text"], input[type="date"], input[type="number"] { padding: 8px; border: 1px solid #ccc; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="card">
        <h2>License Management Server</h2>
        <p>This panel shows all Salesforce orgs that have installed your package and registered a trial.</p>

        <?php
        // Handle Admin Form Submission to generate a new key
        if (isset($_POST['generate_key'])) {
            $new_key = 'KEY-' . strtoupper(bin2hex(random_bytes(8)));
            $expiry = $_POST['expiry'] ?? date('Y-m-d', strtotime('+1 year'));
            $max_pages = $_POST['max_pages'] ?? 10;
            
            $stmt = $pdo->prepare("INSERT INTO licenses (license_key, status, expiration_date, max_pages) VALUES (?, 'Unclaimed', ?, ?)");
            $stmt->execute([$new_key, $expiry, $max_pages]);
            
            // Redirect to avoid form resubmission on refresh
            header("Location: ?new_key=" . urlencode($new_key));
            exit;
        }

        // Show success message if redirected
        if (isset($_GET['new_key'])) {
            $new_key = htmlspecialchars($_GET['new_key']);
            echo "<p style='color:green'>Generated New Key: <strong>$new_key</strong></p>";
        }
        ?>

        <!-- Generate Key Form -->
        <div style="background: #e9ecef; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
            <h3>Generate New Activation Key</h3>
            <form method="POST">
                <label>Expiration Date:</label>
                <input type="date" name="expiry" value="<?php echo date('Y-m-d', strtotime('+1 year')); ?>" required>
                
                <label style="margin-left: 15px;">Max Pages Allowed:</label>
                <input type="number" name="max_pages" value="10" required>
                
                <button type="submit" name="generate_key" class="btn" style="margin-left: 15px;">Generate Key</button>
            </form>
        </div>

        <!-- Licenses Table -->
        <table>
            <thead>
                <tr>
                    <th>Org ID</th>
                    <th>Company Name</th>
                    <th>Email</th>
                    <th>License Key</th>
                    <th>Status</th>
                    <th>Expires</th>
                    <th>Max Pages</th>
                </tr>
            </thead>
            <tbody>
                <?php
                $stmt = $pdo->query("SELECT * FROM licenses ORDER BY created_at DESC");
                while ($row = $stmt->fetch()) {
                    $statusClass = 'badge-trial';
                    if ($row['status'] === 'Active') $statusClass = 'badge-active';
                    if ($row['status'] === 'Expired' || strtotime($row['expiration_date']) < time()) {
                        $statusClass = 'badge-expired';
                        $row['status'] = 'Expired';
                    }
                    if ($row['status'] === 'Unclaimed') $statusClass = '';

                    echo "<tr>
                        <td>" . htmlspecialchars($row['org_id'] ?? 'N/A') . "</td>
                        <td>" . htmlspecialchars($row['company_name'] ?? 'N/A') . "</td>
                        <td>" . htmlspecialchars($row['admin_email'] ?? 'N/A') . "</td>
                        <td><code>" . htmlspecialchars($row['license_key']) . "</code></td>
                        <td><span class='$statusClass'>" . htmlspecialchars($row['status']) . "</span></td>
                        <td>" . htmlspecialchars($row['expiration_date']) . "</td>
                        <td>" . htmlspecialchars($row['max_pages']) . "</td>
                    </tr>";
                }
                ?>
            </tbody>
        </table>
    </div>
</body>
</html>
