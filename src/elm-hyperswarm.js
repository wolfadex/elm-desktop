const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const Hyperswarm = require("hyperswarm");
const sodium = require("sodium-native");

// let appName;
// let secretPath;
// let secret;
// let payloadKey;
// let topic;
// let swarm;
// let discovery;

function hkdf(secret, info, length = 32) {
  const raw = crypto.hkdfSync("sha256", secret, Buffer.alloc(0), info, length);
  return Buffer.from(raw);
}

function encrypt(message, key) {
  const nonce = crypto.randomBytes(sodium.crypto_secretbox_NONCEBYTES);
  const cipher = Buffer.alloc(
    message.length + sodium.crypto_secretbox_MACBYTES,
  );
  sodium.crypto_secretbox_easy(cipher, message, nonce, key);
  return Buffer.concat([nonce, cipher]); // prepend nonce so decrypt can read it
}

function decrypt(payload, key) {
  const nonce = payload.subarray(0, sodium.crypto_secretbox_NONCEBYTES);
  const cipher = payload.subarray(sodium.crypto_secretbox_NONCEBYTES);
  const message = Buffer.alloc(
    cipher.length - sodium.crypto_secretbox_MACBYTES,
  );
  if (!sodium.crypto_secretbox_open_easy(message, cipher, nonce, key)) {
    return [false];
  }
  return [true, message];
}

async function joinSwarm({
  secret,
  payloadKey,
  topic,
  //
  onJoined,
  onDataReceived,
  onClose,
  onPeerConnected,
  onError,
  sendData,
}) {
  const swarm = new Hyperswarm();
  const myPublicKey = swarm.keyPair.publicKey.toString("hex");
  const discovery = swarm.join(topic, { server: true, client: true });

  swarm.on("connection", (socket, info) => {
    socket.on("data", (data) => {
      const [success, plain] = decrypt(data, payloadKey);

      onDataReceived([success, plain?.toString() || ""]);
    });
    socket.on("error", (err) => {
      if (err.code !== "ECONNRESET") {
        // TODO
        console.error("Socket error:", err.message);
      }
      onError(err.code);
    });
    socket.on("close", () => {
      onClose(info.publicKey.toString("hex"));
    });

    sendData(function (data) {
      socket.write(encrypt(data, payloadKey));
    });

    onPeerConnected([info.publicKey.toString("hex"), socket]);
  });

  try {
    await discovery.flushed();
  } catch (error) {
    // TODO
    console.error(error);
  }

  process.on("SIGINT", async () => {
    if (swarm) {
      await swarm.destroy();
    }

    process.exit(0);
  });

  onJoined({
    secret: secret,
    payloadKey: payloadKey,
    topic: topic,
    myPublicKey: myPublicKey,
  });
}

function secretExists(appName, callback) {
  const secretPath = path.join(process.env.HOME, `.${appName}`, "secret");

  if (fs.existsSync(secretPath)) {
    const secret = fs.readFileSync(secretPath);
    callback(secret.toString("base64url"));
  } else {
    callback(null);
  }
}

function initialize(appName, callback) {
  const secretPath = path.join(process.env.HOME, `.${appName}`, "secret");
  let secret;

  if (fs.existsSync(secretPath)) {
    secret = fs.readFileSync(secretPath);
  } else {
    secret = crypto.randomBytes(32);
    fs.mkdirSync(path.dirname(secretPath), { recursive: true });
    fs.writeFileSync(secretPath, secret, { mode: 0o600 }); // owner-only read/write
  }

  const topic = hkdf(secret, `${appName}-swarm-topic-v1`); // used for swarm.join()
  const payloadKey = hkdf(secret, `${appName}-payload-key-v1`); // used for encrypting data

  callback({
    secret: secret.toString("base64url"),
    topic: topic,
    payloadKey: payloadKey,
  });
}

function initializeFromSecret(appName, base64Secret, callback) {
  const secretPath = path.join(process.env.HOME, `.${appName}`, "secret");
  const secret = Buffer.from(base64Secret, "base64url");
  fs.mkdirSync(path.dirname(secretPath), { recursive: true });
  fs.writeFileSync(secretPath, secret, { mode: 0o600 });
  const topic = hkdf(secret, `${appName}-swarm-topic-v1`); // used for swarm.join()
  const payloadKey = hkdf(secret, `${appName}-payload-key-v1`); // used for encrypting data
  callback({ secret: base64Secret, topic: topic, payloadKey: payloadKey });
}

module.exports = {
  secretExists: secretExists,
  initialize: initialize,
  initializeFromSecret: initializeFromSecret,
  joinSwarm: joinSwarm,
};
