"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.listAllowedUsers = exports.removeFromAllowlist = exports.addToAllowlist = exports.beforeSignIn = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
// Blocking function: runs before sign-in/sign-up
// Rejects authentication if user's UID is not in the allowlist
exports.beforeSignIn = functions.auth.user().beforeSignIn(async (user, context) => {
    const uid = user.uid;
    // Check if user exists in allowlist
    const allowlistDoc = await admin.firestore().doc(`allowlist/${uid}`).get();
    if (!allowlistDoc.exists) {
        // Reject sign-in with a clear error
        throw new functions.auth.HttpsError("permission-denied", "Access denied. Your account is not authorized to use this app. Contact the administrator for access.");
    }
    // Optional: attach custom claims for additional authorization
    const userData = allowlistDoc.data() || {};
    if (userData.role) {
        await admin.auth().setCustomUserClaims(uid, { role: userData.role });
    }
    // Allow sign-in to proceed
    return;
});
// Optional: Function to add users to allowlist (callable from app by admins)
exports.addToAllowlist = functions.https.onCall(async (data, context) => {
    // Only allow if caller has admin role
    if (!context.auth || context.auth.token.role !== "admin") {
        throw new functions.https.HttpsError("permission-denied", "Only admins can add users to the allowlist");
    }
    const { uid, email, role = "user" } = data;
    if (!uid || !email) {
        throw new functions.https.HttpsError("invalid-argument", "uid and email are required");
    }
    await admin.firestore().doc(`allowlist/${uid}`).set({
        email,
        role,
        addedAt: admin.firestore.FieldValue.serverTimestamp(),
        addedBy: context.auth.uid
    });
    // Set custom claims for immediate effect
    await admin.auth().setCustomUserClaims(uid, { role });
    return { success: true };
});
// Optional: Remove user from allowlist
exports.removeFromAllowlist = functions.https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.role !== "admin") {
        throw new functions.https.HttpsError("permission-denied", "Only admins can remove users from the allowlist");
    }
    const { uid } = data;
    if (!uid) {
        throw new functions.https.HttpsError("invalid-argument", "uid is required");
    }
    await admin.firestore().doc(`allowlist/${uid}`).delete();
    await admin.auth().setCustomUserClaims(uid, { role: null });
    // Optionally revoke refresh tokens to force re-auth
    await admin.auth().revokeRefreshTokens(uid);
    return { success: true };
});
// Optional: List all allowed users
exports.listAllowedUsers = functions.https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.role !== "admin") {
        throw new functions.https.HttpsError("permission-denied", "Only admins can list allowed users");
    }
    const snapshot = await admin.firestore().collection("allowlist").get();
    const users = snapshot.docs.map(doc => (Object.assign({ uid: doc.id }, doc.data())));
    return { users };
});
//# sourceMappingURL=index.js.map