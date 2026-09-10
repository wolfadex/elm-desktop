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
    swarm = new Hyperswarm();
    topic = crypto.createHash("sha256").update(appName).digest();
    discovery = swarm.join(topic, { server: true, client: true });

    swarm.on("connection", (socket, info) => {
      console.log(`Connected to peer! (initiator: ${info.client})`);

      socket.on("data", (data) => {
        const dataStr = data.toString();
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

      app.ports.sendData?.subscribe(function (data) {
        socket.write(data);
      });
    });

    try {
      await discovery.flushed();
    } catch (error) {
      // TODO
      console.error(error);
    }

    app.ports.swarmReady.send(null);
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
