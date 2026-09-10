const crypto = require("node:crypto");
const Hyperswarm = require("hyperswarm");

let swarm;
let topic;
let discovery;

// Additional backend code to run
function flags() {
  return {};
}

function ports(app) {
  app.ports.initializeHyperswarm.subscribe(async function (appName) {
    console.log("CARL", 0, appName);
    swarm = new Hyperswarm();
    console.log("CARL", 1);
    topic = crypto.createHash("sha256").update(appName).digest();
    console.log("CARL", 1.5);
    discovery = swarm.join(topic, { server: true, client: true });
    console.log("CARL", 2);

    swarm.on("connection", (socket, info) => {
      console.log(`Connected to peer! (initiator: ${info.client})`);

      socket.on("data", (data) => {
        const dataStr = data.toString();
        console.log("Received:", dataStr);
        app.ports.dataReceived.send(dataStr);
      });
      socket.on("error", (err) => {
        if (err.code !== "ECONNRESET") {
          // TODO
          console.error("Socket error:", err.message);
        }
      });
      socket.on("close", () => {
        // TODO
        console.log(
          "❌ Peer disconnected. Hyperswarm will auto-reconnect when back online.",
        );
      });

      app.ports.sendData.subscribe(function (data) {
        socket.write(data);
      });
    });
    console.log("CARL", 3);
    try {
      await discovery.flushed();
      console.log("CARL", 4);
    } catch (error) {
      // TODO
      console.error(error);
    }

    console.log("CARL", 5);
    app.ports.swarmReady.send(null);
    console.log("CARL", 6);
  });

  process.on("SIGINT", async () => {
    if (swarm) {
      await swarm.destroy();
    }

    process.exit(0);
  });
}

module.exports = {
  flags: flags,
  ports: ports,
};
