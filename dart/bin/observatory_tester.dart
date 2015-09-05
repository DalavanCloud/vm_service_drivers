// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library observatory_tester;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:observatory_lib/observatory_lib.dart';

main(List<String> args) async {
  if (args.length != 1) {
    print('usage: dart tool/observatory/observatory_tester.dart <sdk location>');
    exit(1);
  }

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(print);

  String sdk = args.first;

  print('Using sdk at ${sdk}.');

  // pause_isolates_on_start, pause_isolates_on_exit
  Process process = await Process.start('${sdk}/bin/dart', [
      '--pause_isolates_on_start',
      '--enable-vm-service=${port}',
      'tool/observatory/sample_main.dart'
  ]);

  print('dart process started');

  process.exitCode.then((code) => print('observatory exited: ${code}'));
  process.stdout.transform(UTF8.decoder).listen(print);
  process.stderr.transform(UTF8.decoder).listen(print);

  await new Future.delayed(new Duration(milliseconds: 500));

  WebSocket socket = await WebSocket.connect('ws://$host:$port/ws');

  print('socket connected');

  StreamController<String> _controller = new StreamController();
  socket.listen((data) {
    _controller.add(data);
  });

  observatory = new Observatory(_controller.stream, (String message) {
    socket.add(message);
  });

  observatory.onSend.listen((str)    => print('--> ${str}'));
  observatory.onReceive.listen((str) => print('<-- ${str}'));

  observatory.onIsolateEvent.listen((e) => print('onIsolateEvent: ${e}'));
  observatory.onDebugEvent.listen((e) => print('onDebugEvent: ${e}'));
  observatory.onGcEvent.listen((e) => print('onGcEvent: ${e}'));
  observatory.onStdoutEvent.listen((e) => print('onStdoutEvent: ${e}'));
  observatory.onStderrEvent.listen((e) => print('onStderrEvent: ${e}'));

  observatory.streamListen('Isolate');
  observatory.streamListen('Debug');
  observatory.streamListen('Stdout');

  VM vm = await observatory.getVM();
  print(await observatory.getVersion());
  List<IsolateRef> isolates = await vm.isolates;
  print(isolates);

  IsolateRef isolateRef = isolates.first;
  print(await observatory.resume(isolateRef.id));

  observatory.dispose();
  socket.close();
  process.kill();
}

// TODO: connect to the observatory

// TODO: perform some actions

// TODO: listen for events

final String host = 'localhost';
Observatory observatory;

final int port = 7575;
