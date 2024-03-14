s.boot;
s.quit;
Server.killAll; // om udp socket address används

s.scope;
s.freqscope;
Window.browse; // använd browse för att se alla argument osv som något har

//////////////////////////////////////////////
// KODEN

// skapa en array av buffrar och använd path för att fylla med låtar
(
var folder = PathName.new(thisProcess.nowExecutingPath.dirname ++ "/billboard1936/");
folder.postln;
Buffer.freeAll;

// globala variabler
~crossfade = 5; // sätt 0 för hårdklipp (måste starta om för ändring)
~noiseOn = true; // sätt false för att stänga av radiobrus
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
	~media = ~media.add(Buffer.read(s, path.fullPath));
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
	arg gate=0, amp=1.0, pan=0, prevpan=0, angle=0, buf, trig=1, loop=0;
	var sig, env, sample1, sample2;

	env = Env(levels: [0, 1, 0], times: [1, 1]);
	sample1 = PlayBuf.ar(2, ~radiosample1, BufRateScale.kr(~radiosample1), loop: 1);
	sample2 = PlayBuf.ar(2, ~radiosample2, BufRateScale.kr(~radiosample2), loop: 1);

	sig = ClipNoise.ar(amp);

	sig = (sig + Crackle.ar(1.8,amp))/2;

	sig = Pan2.ar(sig, pan)/8;

	sig = amp * (sig + sample1 + sample2) * EnvGen.kr(env, gate);

	Out.ar(0, sig);
}).add;

// funktion som ändrar låt baserat på sliders värde

~synth0 = Synth.new(\player, [\bufnum, ~media[0]], s).register;
~synth1 = Synth.new(\player, [\bufnum, ~media[1]], s).register;
~radionoise = Synth.new(\radionoise, s).register;

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

//////////////////////////////////////////////
// GUI
// OBS! understreck = skickar argument till metod automatiskt, ger mindre brackets

// TODO range: INTE 100% JÄMT MAPPAD, KANTLÅTAR ENDAST HÄLFTEN SÅ STORT OMRÅDE I SLIDER!!!
(
var win, year, range, sl;
Window.closeAll;
win= Window.new("Timetravel_alpha", Rect(500,500,700,100));
win.alwaysOnTop_(true);
win.onClose_({ ~synth0.free; ~synth1.free; ~radionoise.free; });
win.front;
range = ControlSpec(minval: 0, maxval: 88, warp: \linear, step: 1);
year = NumberBox(w, Rect(20, 20, 150, 20)).align_(\center).background_(Color.clear);
sl = Slider(win).orientation_(\horizontal);
sl.action_({arg v; ~songSelector.(range.map(sl.value))});
sl.addAction({ |sl| year.value_(range.map(sl.value) + 1935)});
win.layout_(VLayout(year, sl));
)

~media[30].postln;

( // BARA ETT TEST HÄR!!!
var win, slider, button;
Window.closeAll;
win= Window.new("Timetravell_test", Rect(1500,500,700,500));
win.alwaysOnTop(true);
win.front;
slider = 8.collect({Slider.new()});
button = 8.collect({Button.new()});
win.layout_(GridLayout.rows(slider, button));
)



~sl.value_(0.2);
~sl.valueAction_(0.8); // sätter värdet + callar action också

~sl.visible_(1);
~sl.enabled_(1);
~sl.background_(Color.rand);
~sl.orientation_(\horizontal);


Window.screenBounds;








(
SynthDef(\sine, {
	arg freq = 440, amp = 0.5, out = 0;
	var sig;
	sig = SinOsc.ar(freq, 0, amp);
	Out.ar(out, sig);
}).add;
)

// Group of synths playing sine wave in 8 channels
(
8.do({ |i|
	Synth(\sine, [\freq, 220 * (i + 1), \amp, 0.2, \out, i]);
});
)

// Stop the synths after a certain duration (in seconds)
CmdPeriod.run({
	8.do({ |i|
		Synth(\sine, [\freq, 220 * (i + 1), \amp, 0, \out, i]);
	});
});
