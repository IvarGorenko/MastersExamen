s.boot;
s.quit;
Server.killAll; // om udp socket address används

s.scope;
s.freqscope;
Window.browse; // använd browse för att se alla argument osv som något har

//////////////////////////////////////////////
// KODEN


(
//var distance0 = 0;
// Starta OSC och lyssna på meddelanden
OSCdef.new(\earth,
	{
		arg msg;

		var distance_light = msg[1]/9.4607e+12;
		var speed = msg[2]/(1e+11 * distance_light); // konstant * distans för att kompensera för att hastigheten är snabbare med större distans, ger att speed (och crossfade) blir konstant vid samma musposition
		var direction = msg[3];
		// speed calc from discrete derivative: speed = (distance - distance0)/time
		//var distance = msg[1];
		//var speed = abs(distance - distance0)/time;
		//distance0 = distance.value;
		("Distance in lightyears:" + distance_light).postln;
		("speed:" + speed).postln;
		("direction:" + direction).postln;
		//("fn1:" + distance).postln;
		//("fn:" + distance0).postln;
		//("speed:" + speed).postln;

		distance_light = distance_light.asInteger;
		if (distance_light < 89) {~songSelector.value(distance_light);};

		if (speed < 0.2, {~crossfade = 1/0.2}, {~crossfade = 1/speed;}); // hastighet kan bli för låg



	},'/Earth');
)

(
OSCdef.new(\time,
	{
		arg msg;
		var focus = msg[1];

		("Focus:" + focus).postln;
		//("Angle:" + msg[2]).postln;

	},'/TimeTravel');
)


// skapa en array av buffrar och använd path för att fylla med låtar
(
var folder = PathName.new(thisProcess.nowExecutingPath.dirname ++ "/billboard1936/");
folder.postln;
Buffer.freeAll;

// globala variabler
~crossfade; // sätt 0 för hårdklipp, 5 för vanligt
~noiseOn = false; // sätt false för att stänga av radiobrus
~toggle = 1; // toggle visar vilken av syntarna som nuvarande vald låt spelas på
~currentSong = 0;
~synth0; ~synth1;
~radionoise;
~songSelector;
~radiosample1 = Buffer.read(s, thisProcess.nowExecutingPath.dirname ++ "/radiosample1_stereo.wav");
~radiosample2 = Buffer.read(s, thisProcess.nowExecutingPath.dirname ++ "/radiosample2_stereo.wav");
~media = Array.new;

folder.entries.do({
	arg path;
	~media = ~media.addFirst(Buffer.read(s, path.fullPath));
});
)

(
SynthDef(\player, { arg out, bufnum, amp = 0, crossfade;
	// buffratescale för att få samma samplingsfrekvens på alla, skalar om dem
	var sig = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), loop: 1);
	sig = sig * amp.lag(crossfade); // fading med lag, minska laghastighet när låtar byter snabbare?
	Out.ar(out, sig); // TODO: arg out kan tas bort? byt ut den mot 0 bara
}).add;

// radionoise synth från Elias kod
SynthDef(\radionoise, {
	arg gate=0, amp=1, pan=0, prevpan=0, angle=0, buf, trig=1, loop=0;
	var sig, env, sample1, sample2;

	env = Env(levels: [0, 1, 0], times: [1, 1]);
	sample1 = PlayBuf.ar(2, ~radiosample1, BufRateScale.kr(~radiosample1), loop: 1);
	sample2 = PlayBuf.ar(2, ~radiosample2, BufRateScale.kr(~radiosample2), loop: 1);

	sig = ClipNoise.ar(amp);

	sig = (sig + Crackle.ar(1.8,amp));

	sig = Pan2.ar(sig, pan);

	sig = amp * (sig + sample1 + sample2) * EnvGen.kr(env, gate);

	Out.ar(0, sig);
}).add;

// funktion som ändrar låt baserat på sliders värde

~synth0 = Synth.new(\player, [\bufnum, ~media[0]], s).register;
~synth1 = Synth.new(\player, [\bufnum, ~media[1]], s).register;
~synth1.set(\amp, 1); // synth 1 spelar i början, kommer köra tidigaste låten när SC startar
~radionoise = Synth.new(\radionoise).register;
~radionoise.set(\amp, 1.3);

~songSelector = {
	arg slideVal = 0;
	//slideVal = slideVal.asInteger;
	slideVal.postln;
	// Om låten har bytts, spela den i synten som inte används, muta den andra.
	if (slideVal != ~currentSong) {
		// Lägg till noise mellan låtar om den är true. 1.0 wait funkar bäst men vet ej varför...
		if (~noiseOn) {{~radionoise.set(\gate, 1); 1.0.wait; ~radionoise.set(\gate, 0)}.forkIfNeeded;};

		~currentSong = slideVal;
		if (~toggle == 0, {
			~toggle = 1; ~synth1.set(\bufnum, ~media[slideVal], \crossfade, ~crossfade);
			~synth1.set(\amp, 1);
			~synth0.set(\amp, 0); "synth1 playing".postln;
		}, {
			~toggle = 0; ~synth0.set(\bufnum, ~media[slideVal], \crossfade, ~crossfade);
			~synth0.set(\amp, 1);
			~synth1.set(\amp, 0); "synth0 playing".postln;
		};)
	};
};
)

~radionoise.remove;
