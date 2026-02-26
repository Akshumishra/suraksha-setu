"use client";

import { useEffect, useState } from "react";
import { db } from "../firebase";
import { collection, onSnapshot } from "firebase/firestore";

export default function Home() {
  const [connected, setConnected] = useState(false);
  const [data, setData] = useState<any[]>([]);

  useEffect(() => {
    const unsubscribe = onSnapshot(
      collection(db, "sos"),
      (querySnapshot) => {
        const items = querySnapshot.docs.map((doc) => doc.data());
        setData(items);
        setConnected(true);
      },
      (err) => console.error("Firebase real-time error:", err),
    );

    return () => unsubscribe();
  }, []);

  return (
    <div style={{ fontFamily: "sans-serif", padding: "40px" }}>
      <h1>SurakshaSetu Dashboard</h1>
      {connected ? (
        <p style={{ color: "green" }}>Connected to Firebase</p>
      ) : (
        <p style={{ color: "red" }}>Not connected</p>
      )}
      <hr />
      <h2>SOS Reports (Live Feed):</h2>
      {data.length > 0 ? (
        <ul>
          {data.map((item, index) => (
            <li key={index}>
              <strong>{item.status ?? "active"}</strong> - (
              {item.lat ?? "NA"}, {item.lon ?? "NA"})
            </li>
          ))}
        </ul>
      ) : (
        <p>No SOS reports yet</p>
      )}
    </div>
  );
}
