const admin = require("firebase-admin");

const ADMIN_USERNAME = "AkshuDeep";
const ADMIN_EMAIL = "surakshasetu47@gmail.com";
const ADMIN_PASSWORD = "D162003@212004A";

admin.initializeApp();

async function ensureAdminAccount() {
  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(ADMIN_EMAIL);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") {
      throw error;
    }
    userRecord = await admin.auth().createUser({
      email: ADMIN_EMAIL,
      password: ADMIN_PASSWORD,
      displayName: ADMIN_USERNAME,
      disabled: false,
    });
  }

  await admin.auth().updateUser(userRecord.uid, {
    displayName: ADMIN_USERNAME,
    password: ADMIN_PASSWORD,
    disabled: false,
  });

  await admin.auth().setCustomUserClaims(userRecord.uid, {
    role: "admin",
  });

  await admin.firestore().collection("users").doc(userRecord.uid).set(
      {
        name: ADMIN_USERNAME,
        email: ADMIN_EMAIL,
        role: "admin",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  return userRecord.uid;
}

ensureAdminAccount()
    .then((uid) => {
      console.log(`Admin account is ready: ${uid}`);
      process.exit(0);
    })
    .catch((error) => {
      console.error("Failed to seed admin account", error);
      process.exit(1);
    });
