// dashboard/firebase.js
import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyDULE278J9wsfKf9o1cd-rXbqJ2A2OQVRg",
  authDomain: "suraksha-setu-9808d.firebaseapp.com",
  projectId: "suraksha-setu-9808d",
  storageBucket: "suraksha-setu-9808d.appspot.com",
  messagingSenderId: "179434683012",
  appId: "1:179434683012:android:60a0507cbfc55d904ae0d1"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
