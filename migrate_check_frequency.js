const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrateCheckFrequency() {
  const itemsRef = db.collection("items");
  const snapshot = await itemsRef.get();

  console.log(`Found ${snapshot.size} items to migrate`);

  let updated = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    
    // Skip if already has checkFrequency
    if (data.checkFrequency) {
      console.log(`Skipping ${data.name} - already has checkFrequency: ${data.checkFrequency}`);
      continue;
    }

    // Default to "service" for all existing items
    // You can customize this logic based on category if needed
    const checkFrequency = "service";
    
    await itemsRef.doc(doc.id).update({
      checkFrequency: checkFrequency,
      required: data.required ?? false,
      // Don't set lastCheckedAt - leave null so they show as "overdue" initially
    });

    console.log(`Updated: ${data.name} -> checkFrequency: ${checkFrequency}`);
    updated++;
  }

  console.log(`\nMigration complete. Updated ${updated} items.`);
  process.exit(0);
}

migrateCheckFrequency().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
