const elmHyperswarm = require("./elm-hyperswarm");

// Additional backend code to run
function flags() {
  return {};
}

function ports(app) {
  app.ports.checkExistingSecret.subscribe(function (name) {
    elmHyperswarm.secretExists(name, app.ports.doesSecretExist.send);
  });
  app.ports.createNotesStore.subscribe(function (name) {
    elmHyperswarm.initialize(name, app.ports.storeReady.send);
  });

  app.ports.joinNotesStore.subscribe(function ([name, base64Secret]) {
    elmHyperswarm.initializeFromSecret(
      name,
      base64Secret,
      app.ports.storeReady.send,
    );
  });

  app.ports.joinHyperswarm.subscribe(function (data) {
    elmHyperswarm.joinSwarm({
      secret: data.secret,
      payloadKey: data.payloadKey,
      topic: data.topic,
      //
      onJoined: app.ports.swarmReady.send,
      onDataReceived: app.ports.dataReceived.send,
      onClose: app.ports.peerDisconnected.send,
      onPeerConnected: app.ports.peerConnected.send,
      onError: app.ports.swarmError.send,
      sendData: app.ports.sendData.subscribe,
    });
  });
}

module.exports = {
  flags: flags,
  ports: ports,
};
