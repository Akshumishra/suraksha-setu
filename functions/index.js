const crypto = require("crypto");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");

admin.initializeApp();
const db = admin.firestore();

const SMTP_HOST = process.env.SMTP_HOST;
const SMTP_PORT = Number(process.env.SMTP_PORT || "587");
const SMTP_USER = process.env.SMTP_USER;
const SMTP_PASS = process.env.SMTP_PASS;
const SMTP_FROM = process.env.SMTP_FROM || "no-reply@surakshasetu.in";
const OFFICIAL_EMAIL_DOMAINS = (process.env.OFFICIAL_EMAIL_DOMAINS ||
  "police.gov.in,gov.in")
    .split(",")
    .map((domain) => domain.trim().toLowerCase())
    .filter(Boolean);

function normalizePoliceId(policeId) {
  return policeId.trim().toUpperCase().replace(/[^A-Z0-9_-]/g, "");
}

function normalizePhone(phone) {
  return phone.trim().replace(/\s+/g, "");
}

function isAllowedOfficialEmail(email) {
  const normalized = email.trim().toLowerCase();
  const atIndex = normalized.lastIndexOf("@");
  if (atIndex < 0) return false;
  const domain = normalized.substring(atIndex + 1);
  return OFFICIAL_EMAIL_DOMAINS.includes(domain);
}

function validateRegistrationPayload(rawData) {
  const data = rawData || {};
  const officerName = String(data.officerName || "").trim();
  const policeId = normalizePoliceId(String(data.policeId || ""));
  const email = String(data.email || "").trim().toLowerCase();
  const stationName = String(data.stationName || "").trim();
  const contactNumber = normalizePhone(String(data.contactNumber || ""));
  const latitude = Number(data.latitude);
  const longitude = Number(data.longitude);
  const jurisdictionRadius = Number(data.jurisdictionRadius);
  const idProofUrl = String(data.idProofUrl || "").trim();

  if (!officerName || !policeId || !email || !stationName || !contactNumber) {
    throw new HttpsError("invalid-argument", "Missing required registration fields.");
  }
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new HttpsError("invalid-argument", "Invalid station latitude.");
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new HttpsError("invalid-argument", "Invalid station longitude.");
  }
  if (!Number.isFinite(jurisdictionRadius) || jurisdictionRadius <= 0) {
    throw new HttpsError("invalid-argument", "Jurisdiction radius must be positive.");
  }
  if (!isAllowedOfficialEmail(email)) {
    throw new HttpsError("invalid-argument", "Official email domain is not allowed.");
  }

  return {
    officerName,
    policeId,
    email,
    stationName,
    contactNumber,
    latitude,
    longitude,
    jurisdictionRadius,
    idProofUrl: idProofUrl || null,
  };
}

async function assertAdmin(contextAuth) {
  if (!contextAuth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const claimRole = String(contextAuth.token?.role || "").toLowerCase();
  if (claimRole === "admin") {
    return contextAuth.uid;
  }

  const userDoc = await db.collection("users").doc(contextAuth.uid).get();
  const userRole = String(userDoc.data()?.role || "").toLowerCase();
  if (userRole !== "admin") {
    throw new HttpsError("permission-denied", "Admin role required.");
  }
  return contextAuth.uid;
}

function generateSecurePassword(length = 18) {
  const upper = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  const lower = "abcdefghijkmnopqrstuvwxyz";
  const digits = "23456789";
  const symbols = "!@#%^*()-_=+";
  const allChars = upper + lower + digits + symbols;

  const mandatory = [
    upper[crypto.randomInt(upper.length)],
    lower[crypto.randomInt(lower.length)],
    digits[crypto.randomInt(digits.length)],
    symbols[crypto.randomInt(symbols.length)],
  ];

  const remainingLength = Math.max(length - mandatory.length, 0);
  const randomPart = Array.from({length: remainingLength}, () => {
    return allChars[crypto.randomInt(allChars.length)];
  });

  const passwordChars = [...mandatory, ...randomPart];
  for (let i = passwordChars.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [passwordChars[i], passwordChars[j]] = [passwordChars[j], passwordChars[i]];
  }
  return passwordChars.join("");
}

async function sendPoliceCredentialsEmail({
  to,
  officerName,
  stationName,
  password,
}) {
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) {
    throw new Error("SMTP credentials are not configured.");
  }

  const transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: {
      user: SMTP_USER,
      pass: SMTP_PASS,
    },
  });

  const subject = "Suraksha Setu Police Dashboard Access Approved";
  const text = [
    `Dear ${officerName},`,
    "",
    "Your police registration has been approved.",
    `Station: ${stationName}`,
    `Login Email: ${to}`,
    `Temporary Password: ${password}`,
    "",
    "Please log in to the Suraksha Setu Police Dashboard and change your password immediately.",
  ].join("\n");

  await transporter.sendMail({
    from: SMTP_FROM,
    to,
    subject,
    text,
  });
}

exports.submitPoliceRegistrationRequest = onCall(async (request) => {
  const payload = validateRegistrationPayload(request.data);
  const requestRef = db.collection("police_registration_requests").doc(payload.policeId);

  const stationSnapshot = await db.collection("police_stations")
      .where("policeId", "==", payload.policeId)
      .limit(1)
      .get();
  if (!stationSnapshot.empty) {
    throw new HttpsError("already-exists", "Police ID is already registered.");
  }

  const existing = await requestRef.get();
  if (existing.exists) {
    throw new HttpsError("already-exists", "Registration request already exists for this Police ID.");
  }

  await requestRef.create({
    ...payload,
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  logger.info("Police registration submitted", {
    requestId: requestRef.id,
    policeId: payload.policeId,
    stationName: payload.stationName,
  });

  return {
    requestId: requestRef.id,
    status: "pending",
  };
});

exports.approvePoliceRegistrationRequest = onCall(async (request) => {
  const adminUid = await assertAdmin(request.auth);
  const requestId = String(request.data?.requestId || "").trim();
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }

  const requestRef = db.collection("police_registration_requests").doc(requestId);
  const registration = await requestRef.get();
  if (!registration.exists) {
    throw new HttpsError("not-found", "Registration request not found.");
  }

  const data = registration.data() || {};
  if (data.status !== "pending") {
    throw new HttpsError("failed-precondition", "Only pending requests can be approved.");
  }

  const payload = validateRegistrationPayload(data);
  const duplicateStation = await db.collection("police_stations")
      .where("policeId", "==", payload.policeId)
      .limit(1)
      .get();
  if (!duplicateStation.empty) {
    throw new HttpsError("already-exists", "This police ID already has a station record.");
  }

  let existingAuthUser = null;
  try {
    existingAuthUser = await admin.auth().getUserByEmail(payload.email);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      throw new HttpsError("internal", "Could not validate police email uniqueness.");
    }
  }
  if (existingAuthUser) {
    throw new HttpsError("already-exists", "An account already exists for this email.");
  }

  const temporaryPassword = generateSecurePassword();
  let userRecord;
  const stationRef = db.collection("police_stations").doc();
  try {
    userRecord = await admin.auth().createUser({
      email: payload.email,
      password: temporaryPassword,
      displayName: payload.officerName,
      disabled: false,
    });

    await admin.auth().setCustomUserClaims(userRecord.uid, {
      role: "police",
      stationId: stationRef.id,
      policeId: payload.policeId,
    });

    const batch = db.batch();
    batch.set(stationRef, {
      officerName: payload.officerName,
      policeId: payload.policeId,
      email: payload.email,
      stationName: payload.stationName,
      contactNumber: payload.contactNumber,
      latitude: payload.latitude,
      longitude: payload.longitude,
      jurisdictionRadius: payload.jurisdictionRadius,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    batch.set(db.collection("users").doc(userRecord.uid), {
      role: "police",
      stationId: stationRef.id,
      policeId: payload.policeId,
      email: payload.email,
      officerName: payload.officerName,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    batch.update(requestRef, {
      status: "approved",
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: adminUid,
      policeUid: userRecord.uid,
      stationId: stationRef.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      emailDeliveryStatus: "pending",
    });

    await batch.commit();
  } catch (error) {
    if (userRecord?.uid) {
      try {
        await admin.auth().deleteUser(userRecord.uid);
      } catch (rollbackError) {
        logger.error("Failed to rollback police auth user", rollbackError);
      }
    }
    logger.error("Police approval transaction failed", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "Approval failed due to server error.");
  }

  let emailDeliveryStatus = "sent";
  try {
    await sendPoliceCredentialsEmail({
      to: payload.email,
      officerName: payload.officerName,
      stationName: payload.stationName,
      password: temporaryPassword,
    });
    await requestRef.update({
      emailDeliveryStatus: "sent",
      credentialsSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    emailDeliveryStatus = "failed";
    logger.error("Failed to send police onboarding email", error);
    await requestRef.update({
      emailDeliveryStatus: "failed",
      emailError: String(error?.message || error),
    });
  }
  logger.info("Police registration approved", {
    requestId,
    policeUid: userRecord.uid,
    stationId: stationRef.id,
    emailDeliveryStatus,
  });

  return {
    requestId,
    stationId: stationRef.id,
    policeUid: userRecord.uid,
    emailDeliveryStatus,
  };
});

exports.rejectPoliceRegistrationRequest = onCall(async (request) => {
  const adminUid = await assertAdmin(request.auth);
  const requestId = String(request.data?.requestId || "").trim();
  const reason = String(request.data?.reason || "").trim();

  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }

  const requestRef = db.collection("police_registration_requests").doc(requestId);
  const registration = await requestRef.get();
  if (!registration.exists) {
    throw new HttpsError("not-found", "Registration request not found.");
  }

  const data = registration.data() || {};
  if (data.status !== "pending") {
    throw new HttpsError("failed-precondition", "Only pending requests can be rejected.");
  }

  await requestRef.update({
    status: "rejected",
    rejectionReason: reason || null,
    rejectedBy: adminUid,
    rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  logger.info("Police registration rejected", {
    requestId,
    rejectedBy: adminUid,
  });

  return {requestId, status: "rejected"};
});
