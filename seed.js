const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function seed() {
  await db.collection("items").doc("eggs").set({
    name: "Eggs",
    unitLabel: "cartons",
    amountPerService: 5,
    truckAmount: 5,
    homeAmount: 20,
    criticalServices: 5,
    lowWarningServices: 7,
    desiredBufferServices: 8,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: "system",
  });

  console.log("Seed complete");
  process.exit();
}

seed();