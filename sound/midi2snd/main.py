from dataclasses import dataclass

import click
from mido import MidiFile, MidiTrack


class SndEvent:
    def to_snd(self):
        pass


@dataclass
class Event:
    time: int
    pass


@dataclass
class EndOfTrackEvent(Event):
    pass


@dataclass
class ChannelEvent(Event):
    channel: int


@dataclass
class NoteOffEvent(ChannelEvent, SndEvent):
    def to_snd(self):
        pass


@dataclass
class NoteEvent(ChannelEvent, SndEvent):
    note: int
    velocity: int

    @property
    def frequency(self) -> float:
        return 440 * pow(2, (self.note - 69) / 12)

    @property
    def freq_val(self) -> int:
        return round(3_579_540 / (32 * self.frequency))

    @property
    def attenuation(self) -> int:
        return round(1 - (self.velocity / 100) * 16)

    def to_snd(self):
        pass


@dataclass
class WaitEvent(SndEvent):
    midi_ticks: int
    pcjr_ticks: int

    def to_snd(self):
        pass


@click.group()
def cli():
    pass


# TODO: A better way of filtering might be to walk the whole list, keeping track of the current volume, frequency
# and time (in SND) terms per channel, and skipping messages that don't change it.


@cli.command(help="Converts a MIDI file to a Fosterquest SND file")
@click.argument("filename")
def convert(filename: str):
    mid = MidiFile(filename)

    def parse_track(track: MidiTrack):
        t = 0
        for e in track:
            t += e.time
            if e.type == "note_on":
                yield NoteEvent(t, e.channel, e.note, e.velocity)
            elif e.type == "note_off":
                yield NoteOffEvent(t, e.channel)
            elif e.type == "end_of_track":
                yield EndOfTrackEvent(t)

    events = sorted(
        (e for t in mid.tracks for e in parse_track(t)), key=lambda e: e.time
    )

    # Delete duplicate EOTs (every track has one)
    while isinstance(events[-2], EndOfTrackEvent):
        del events[-1]

    # Adjust to t=0
    if events[0].time != 0:
        for e in events:
            e.time -= events[0].time

    # Find first tempo message
    us_per_beat = next(m for t in mid.tracks for m in t if m.type == "set_tempo").tempo
    msec_per_tick = us_per_beat / mid.ticks_per_beat / 1_000

    # Insert wait events
    i, t = 0, 0
    while i < len(events):
        if events[i].time > t:
            midi_ticks = events[i].time - t
            pcjr_ticks = round(midi_ticks * msec_per_tick / 54.9255)
            t = events[i].time
            if pcjr_ticks > 0:
                events.insert(i, WaitEvent(midi_ticks, pcjr_ticks))
                i += 1
        i += 1

    # Remove note-off events where we immediately start playing another note on the same channel
    channel_on = []
    to_remove = []
    for e in reversed(events):
        if isinstance(e, WaitEvent):
            channel_on.clear()
        elif isinstance(e, NoteEvent):
            channel_on.append(e.channel)
        elif isinstance(e, NoteOffEvent):
            if e.channel in channel_on:
                to_remove.append(e)

    for e in to_remove:
        events.remove(e)

    for e in events:
        print(e)


if __name__ == "__main__":
    cli()
