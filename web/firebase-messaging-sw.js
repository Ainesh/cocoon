importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAFJCeZ0r-StlWQXMsDI-j_wBcpNs-NAV0",
  authDomain: "couple-space-36e1a.firebaseapp.com",
  projectId: "couple-space-36e1a",
  storageBucket: "couple-space-36e1a.firebasestorage.app",
  messagingSenderId: "459880996436",
  appId: "1:459880996436:web:90b92f7b8ba9b734c857c1",
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((message) => {
  console.log('Background message received:', message);

  const notificationTitle = message.notification?.title || 'Cocoon';
  const notificationOptions = {
    body: message.notification?.body || '',
    icon: '/icons/Icon-192.png',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
