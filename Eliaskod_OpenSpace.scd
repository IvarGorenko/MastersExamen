
//Debug of OSC
NetAddr.langPort;
NetAddr.localAddr;


//Starts the server (or by using ctrl+b)
s.boot;


//0. Starts listening to OSC-data coming from Earth
(
OSCdef.new(\earth,
	{
		arg msg;

		var distance = msg[1]/100000000;

		("Distance:" + distance).postln;

		//("Angle:" + msg[2]).postln;

		~ambientsound.set(\amp, distance);

		~radionoise.set(\amp, 1-distance);

	},'/Earth');
)

//OSC messages
//msg[1] = Name
//msg[1] = distance (amp)
//msg[2] = angle (pan)
//msg[3] = GUI-gate array
	//msg[3][0] = Size/day-gate
	//msg[3][1] = Gravity-gate
	//msg[3][2] = Temperature-gate
	//msg[3][3] = Atmosphere-gate
	//msg[3][4] = Moons-gate
	//msg[3][5] = Rings-gate
//msg[4] = Pos 1st moon
//msg[5] = Pos 2nd moon


// 1. Define filepath and buffers (ctrl + enter)
(
var filePath = thisProcess.nowExecutingPath.dirname;

~b1 = Buffer.read(s, filePath +/+ "radioStatic.wav");
)

// 2. Define Synths (ctrl + enter)
(
	SynthDef(\audiofile, {
		arg gate=0, amp=1, pan=0, prevpan=0, angle=0, buf, trig=1, loop=1;
		var sig, sig1, sig2, env;

		env = EnvGen.kr(
			Env.adsr(1.0,0.0,1.0,1.0),
			gate,
			doneAction:0);

		sig = PlayBuf.ar(1, buf, trigger: trig, loop:1);

		sig = Pan2.ar(sig, pan);

		sig = FreeVerb.ar(sig, 0.5,0.1);
		sig = amp * sig * env;

		Out.ar(0, sig);
	}).add;

	SynthDef(\radionoise, {
		arg gate=0, amp=0.5, pan=0, prevpan=0, angle=0, buf, trig=1, loop=1;
		var sig, sig1, sig2, env;

		env = EnvGen.kr(
			Env.adsr(1.0,0.0,1.0,1.0),
			gate,
			doneAction:0);

	    sig = ClipNoise.ar(amp);

	    sig = (sig + Crackle.ar(1.8,amp))/2;


		sig = Pan2.ar(sig, pan);

		sig = amp* sig * env;

		Out.ar(0, sig);
	}).add;
)

// 3. Start synths (ctrl + enter)
(
~ambientsound = Synth.new(\audiofile, [\buf, ~b1.bufnum]);

~radionoise = Synth.new(\radionoise);
)

// 4. Unmute the synth (shift + enter)
~ambientsound.set(\gate, 1);

//~radionoise.set(\gate, 0);









