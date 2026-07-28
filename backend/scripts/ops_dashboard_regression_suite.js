/**
 * Ride Matching - Operations Dashboard & Matching Engine Automated Regression Suite
 * Self-Diagnosing & Version-Guarded Test Runner
 * 
 * Usage:
 *   node scripts/ops_dashboard_regression_suite.js [HOST] [PORT] [--strict|--full]
 * 
 * Examples:
 *   node scripts/ops_dashboard_regression_suite.js 222.167.207.239 8080 --strict
 *   node scripts/ops_dashboard_regression_suite.js 222.167.207.239 8080 --full
 */

const http = require('http');

const args = process.argv.slice(2);
const isFullMode = args.includes('--full');
const isStrict = !isFullMode; // Default to --strict guard mode

const nonFlagArgs = args.filter(a => !a.startsWith('--'));
const API_HOST = nonFlagArgs[0] || '222.167.207.239';
const API_PORT = parseInt(nonFlagArgs[1] || '8080', 10);
const BASE_URL = `http://${API_HOST}:${API_PORT}`;

const EXPECTED_VERSION = '1.1.0-ops-dashboard';

let adminToken = '';
let testTripId = '';
let testTripOtp = '4820';

function httpRequest(method, path, body = null, token = null) {
  return new Promise((resolve) => {
    const dataString = body ? JSON.stringify(body) : '';
    const headers = {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(dataString),
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request({
      hostname: API_HOST,
      port: API_PORT,
      path: path,
      method: method,
      headers: headers,
      timeout: 5000,
    }, (res) => {
      let resData = '';
      res.on('data', (chunk) => { resData += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(resData);
          resolve({ statusCode: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ statusCode: res.statusCode, raw: resData });
        }
      });
    });

    req.on('error', (err) => resolve({ statusCode: 0, error: err.message }));
    if (body) req.write(dataString);
    req.end();
  });
}

function classifyFailure(statusCode, context) {
  if (statusCode === 404) {
    return {
      diagnosis: `Endpoint non-existent on host (404 Not Found). Running container image is behind source commit (${context}).`,
      action: `Rebuild and deploy backend container on host:\n         -> docker-compose up --build -d backend`
    };
  }
  if (statusCode === 500) {
    return {
      diagnosis: `Internal Server Error (500). Unhandled exception or database/redis query error in endpoint.`,
      action: `Inspect backend process logs:\n         -> docker logs -f ridematching-backend`
    };
  }
  if (statusCode === 403 || statusCode === 401) {
    return {
      diagnosis: `Authorization Failure (${statusCode}). JWT token invalid or missing ADMIN privileges.`,
      action: `Verify credentials in /api/auth/login or JWT secret configuration.`
    };
  }
  if (statusCode === 0) {
    return {
      diagnosis: `Connection Failed. Target host ${BASE_URL} is unreachable.`,
      action: `Check network firewall / process status on target host.`
    };
  }
  return {
    diagnosis: `Unexpected HTTP status ${statusCode}.`,
    action: `Inspect HTTP response body for error details.`
  };
}

async function runRegressionSuite() {
  console.log("==========================================================================");
  console.log(`🧪 OPERATIONS DASHBOARD & MATCHING ENGINE REGRESSION SUITE`);
  console.log(`🎯 Target Host: ${BASE_URL} [Mode: ${isStrict ? 'STRICT GUARD' : 'FULL VERIFICATION'}]`);
  console.log("==========================================================================\n");

  const results = [];

  const logStep = (step, title, success, statusCode, detail, context = '') => {
    const icon = success ? '✅ PASS' : '❌ FAIL';
    console.log(`[${icon}] Step ${step}: ${title} (HTTP ${statusCode})`);
    if (detail) console.log(`         Detail: ${detail}`);

    if (!success) {
      const diag = classifyFailure(statusCode, context || title);
      console.log(`         🔍 Diagnosis: ${diag.diagnosis}`);
      console.log(`         💡 Recommended Action: ${diag.action}`);
    }
    results.push({ step, title, success, statusCode, detail });
  };

  try {
    // -------------------------------------------------------------------
    // STEP 0: STAGE 1 - DEPLOYMENT VERIFICATION (VERSION, METADATA & SHA)
    // -------------------------------------------------------------------
    console.log("👉 Stage 1: Deployment & Build Metadata Verification...");
    const healthCheck = await httpRequest('GET', '/health');
    let isVersionMatch = false;

    if (healthCheck.statusCode === 200) {
      const v = healthCheck.data;
      const runningVersion = v.version || '1.0.0-legacy';
      isVersionMatch = runningVersion === EXPECTED_VERSION;

      console.log(`   Host Status:      ${v.status}`);
      console.log(`   Environment:      ${v.environment || 'production'}`);
      console.log(`   Service Name:     ${v.service || 'ride-matching-backend'}`);
      console.log(`   Container Image:  ${v.containerImage || 'ride-matching-backend:latest'}`);
      console.log(`   Running Version:  ${runningVersion}`);
      console.log(`   Expected Version: ${EXPECTED_VERSION}`);
      console.log(`   Git Commit SHA:   ${v.gitCommit || 'unknown'}`);
      console.log(`   Git Branch:       ${v.branch || 'unknown'}`);
      console.log(`   Build Timestamp:  ${v.buildTime || 'unknown'}\n`);

      if (!isVersionMatch) {
        console.log(`❌ STAGE 1 DEPLOYMENT VERIFICATION FAILED: Target host version (${runningVersion}) does not match source version (${EXPECTED_VERSION}).`);
        console.log(`🔍 Diagnosis: Running backend container image is behind target source commit.`);
        console.log(`💡 Recommended Action: Rebuild and redeploy backend container image on target host:\n         -> docker-compose up --build -d backend\n`);

        if (isStrict) {
          console.log("==========================================================================");
          console.log(`📊 REGRESSION SUITE REPORT`);
          console.log("==========================================================================");
          console.log(`Deployment Verification: ❌ FAILED (Version Mismatch: ${runningVersion} < ${EXPECTED_VERSION})`);
          console.log(`Functional Verification: ⏭ SKIPPED (Deployment Mismatch)`);
          console.log(`Overall Status:          ⚠️ OUTDATED DEPLOYMENT GUARD`);
          console.log("==========================================================================");
          process.exit(1);
        }
      } else {
        console.log(`✅ Stage 1 Deployment Verified: Host running expected build ${runningVersion} (Commit SHA: ${v.gitCommit}, Branch: ${v.branch}).\n`);
      }
    } else {
      console.log(`❌ Health check failed with status ${healthCheck.statusCode}\n`);
      if (isStrict) process.exit(1);
    }

    // -------------------------------------------------------------------
    // STEP 1: AUTHENTICATION & TOKEN ACQUISITION
    // -------------------------------------------------------------------
    console.log("👉 Stage 2 (API & Functional Tests) - Step 1: Admin Authentication...");
    const loginRes = await httpRequest('POST', '/api/auth/login', {
      username: 'admin',
      password: 'admin123'
    });

    if (loginRes.statusCode === 200 && loginRes.data.token) {
      adminToken = loginRes.data.token;
      logStep(1, 'Admin Login & Token Retrieval', true, 200, `Token acquired. User: ${loginRes.data.user?.name}`);
    } else {
      logStep(1, 'Admin Login & Token Retrieval', false, loginRes.statusCode, `Response: ${JSON.stringify(loginRes.data)}`);
      throw new Error('Admin authentication failed. Aborting regression suite.');
    }

    // -------------------------------------------------------------------
    // STEP 2: ENDPOINT REACHABILITY CHECK (ALL 4 ADMIN ENDPOINTS)
    // -------------------------------------------------------------------
    console.log("\n👉 Step 2: Testing Admin Endpoints Reachability...");
    const endpoints = [
      { name: 'Fleet Live', path: '/api/admin/fleet/live' },
      { name: 'Active Trips', path: '/api/admin/trips/active' },
      { name: 'Matching Queue', path: '/api/admin/matching/queue' },
      { name: 'System Health', path: '/api/admin/system/health' },
    ];

    let allReach = true;
    for (const ep of endpoints) {
      const res = await httpRequest('GET', ep.path, null, adminToken);
      if (res.statusCode === 200) {
        console.log(`   ✓ ${ep.name} (${ep.path}) -> 200 OK`);
      } else {
        console.log(`   ✗ ${ep.name} (${ep.path}) -> HTTP ${res.statusCode}`);
        const diag = classifyFailure(res.statusCode, ep.name);
        console.log(`       -> 🔍 ${diag.diagnosis}`);
        allReach = false;
      }
    }
    logStep(2, 'Admin Endpoints 200 OK Reachability Check', allReach, allReach ? 200 : 404, allReach ? 'All 4 Admin endpoints returned 200 OK' : 'One or more admin routes returned 404/error (older image running)', 'admin_ops_routes module');

    // -------------------------------------------------------------------
    // STEP 3: RIDER RIDE REQUEST CREATION
    // -------------------------------------------------------------------
    console.log("\n👉 Step 3: Simulating Rider Search & Trip Request...");
    const tripReq = await httpRequest('POST', '/api/trips/request', {
      pickupLat: 26.8467,
      pickupLng: 80.9462,
      pickupAddress: 'Hazratganj, Lucknow',
      dropoffLat: 26.7606,
      dropoffLng: 80.8893,
      dropoffAddress: 'Lucknow Airport (LKO)',
      vehicleType: 'cab',
      cityId: 'Lucknow'
    }, adminToken);

    if (tripReq.statusCode === 201 && tripReq.data.trip) {
      testTripId = tripReq.data.trip.id;
      if (tripReq.data.trip.riderOtp) {
        testTripOtp = tripReq.data.trip.riderOtp;
      }
      logStep(3, 'Ride Request Creation', true, 201, `Trip #${testTripId.slice(-8)} generated (OTP: ${testTripOtp}). Fare: ₹${tripReq.data.trip.price}`);
    } else {
      logStep(3, 'Ride Request Creation', false, tripReq.statusCode, `Response: ${JSON.stringify(tripReq.data)}`);
    }

    // -------------------------------------------------------------------
    // STEP 4: MATCHING QUEUE & CANDIDATE SCORING AUDIT
    // -------------------------------------------------------------------
    console.log("\n👉 Step 4: Auditing Matching Queue & Candidate Scoring...");
    const queueRes = await httpRequest('GET', '/api/admin/matching/queue', null, adminToken);
    const isQueueSuccess = queueRes.statusCode === 200;
    logStep(4, 'Matching Queue Candidate Diagnostics', isQueueSuccess, queueRes.statusCode, isQueueSuccess ? `Found ${queueRes.data.queue?.length || 0} searching trips` : 'Endpoint non-existent on target host', 'matching queue API');

    // -------------------------------------------------------------------
    // STEP 5: DRIVER ACCEPTANCE & TIMELINE AUDIT
    // -------------------------------------------------------------------
    if (testTripId) {
      console.log("\n👉 Step 5: Simulating Driver Acceptance & Timeline Audit...");
      const acceptRes = await httpRequest('POST', `/api/trips/${testTripId}/accept`, {}, adminToken);
      const isAccepted = acceptRes.statusCode === 200 && acceptRes.data.trip?.status === 'ASSIGNED';
      
      const timelineRes = await httpRequest('GET', `/api/admin/trips/${testTripId}/timeline`, null, adminToken);
      const hasTimeline = timelineRes.statusCode === 200;

      logStep(5, 'Driver Accept & Dispatch Event Audit Log', isAccepted && hasTimeline, acceptRes.statusCode, isAccepted ? `Status: ${acceptRes.data.trip?.status}` : 'Acceptance / Timeline missing', 'dispatch timeline endpoint');

      // -------------------------------------------------------------------
      // STEP 6: FULL RIDE LIFECYCLE (ARRIVED -> IN_PROGRESS -> COMPLETED)
      // -------------------------------------------------------------------
      console.log("\n👉 Step 6: Verifying Full Ride Lifecycle State Transitions...");
      const arriveRes = await httpRequest('POST', `/api/trips/${testTripId}/arrive`, {}, adminToken);
      const startRes = await httpRequest('POST', `/api/trips/${testTripId}/start`, { otp: testTripOtp }, adminToken);
      const completeRes = await httpRequest('POST', `/api/trips/${testTripId}/complete`, {}, adminToken);
      
      const isCompleted = completeRes.statusCode === 200 && completeRes.data.trip?.status === 'COMPLETED';
      logStep(6, 'Full Trip State Transitions (Arrived -> Started -> Completed)', isCompleted, completeRes.statusCode, isCompleted ? `Final Status: COMPLETED (OTP: ${testTripOtp})` : `Arrive: ${arriveRes.statusCode}, Start: ${startRes.statusCode}, Complete: ${completeRes.statusCode}`);
    }

    // -------------------------------------------------------------------
    // STEP 7: SYSTEM INFRASTRUCTURE HEALTH VERIFICATION
    // -------------------------------------------------------------------
    console.log("\n👉 Step 7: System Infrastructure & Service Health Check...");
    const healthRes = await httpRequest('GET', '/api/admin/system/health', null, adminToken);
    const isHealthy = healthRes.statusCode === 200 && healthRes.data.system?.redis === 'healthy';
    logStep(7, 'Infrastructure Health Audit (Redis, DB, WebSockets, Go Engine)', isHealthy, healthRes.statusCode, isHealthy ? `Redis: ${healthRes.data.system?.redis}, DB: ${healthRes.data.system?.database}` : 'Health endpoint missing on host', 'system health endpoint');

    console.log("\n==========================================================================");
    const passCount = results.filter(r => r.success).length;
    console.log(`📊 REGRESSION SUITE REPORT`);
    console.log("==========================================================================");
    console.log(`Deployment Verification: ${isVersionMatch ? '✅ PASSED' : '❌ FAILED'}`);
    console.log(`Functional Verification: ${passCount === results.length ? '✅ PASSED' : '❌ FAILED'} (${passCount}/${results.length})`);
    console.log(`Overall Status:          ${passCount === results.length ? '✅ VERIFIED PRODUCTION READY' : '⚠️ REGRESSION ISSUES DETECTED'}`);
    console.log("==========================================================================");

    process.exit(passCount === results.length ? 0 : 1);
  } catch (err) {
    console.error("\n❌ CRITICAL REGRESSION SUITE ERROR:", err.message);
    process.exit(1);
  }
}

runRegressionSuite();
