import struct
from collections import defaultdict
from dataclasses import dataclass

import click
import mido


@dataclass
class Event:
    pcjr_ticks: int

    def to_snd(self):
        pass


@dataclass
class ChannelEvent(Event):
    channel: int


@dataclass
class VolumeEvent(ChannelEvent):
    volume: int

    @property
    def attenuation(self) -> int:
        return round((1 - (self.volume / 100)) * 15)

    def __str__(self):
        return f"V ch={self.channel}, vol={self.volume}"

    def to_snd(self):
        return struct.pack("<")("V", str(self.channel), f"{self.attenuation:X}h")


@dataclass
class NoteEvent(ChannelEvent):
    note: int

    @property
    def frequency(self) -> float:
        return 440 * pow(2, (self.note - 69) / 12)

    @property
    def freq_val(self) -> int:
        return round(3_579_540 / (32 * self.frequency))

    def __str__(self):
        return ("F", str(self.channel), f"{self.freq_val:X}h")


@dataclass
class WaitEvent(Event):
    duration: int

    def __str__(self):
        return ("W", f"{self.duration:X}h")


@click.group()
def cli():
    pass


# TODO: A better way of filtering might be to walk the whole list, keeping track of the current volume, frequency
# and time (in SND) terms per channel, and skipping messages that don't change it.


@cli.command(help="Converts a MIDI file to a Fosterquest SND file")
@click.argument("filename")
def convert(filename: str):
    mid = mido.MidiFile(filename)

    # Find first tempo message
    us_per_beat = next(e for t in mid.tracks for e in t if e.type == "set_tempo").tempo
    msec_per_tick = us_per_beat / mid.ticks_per_beat / 1_000

    # Convert all relative MIDI ticks into absolute PCjr ticks
    def convert_time(track: mido.MidiTrack):
        midi_ticks = 0
        for e in track:
            midi_ticks += e.time
            e.time = round(midi_ticks * msec_per_tick / 54.9255)
            yield e

    events: list[mido.Message] = sorted(
        (e for t in mid.tracks for e in convert_time(t)), key=lambda e: e.time
    )

    def filter_events(events: list[mido.Message]):
        @dataclass
        class ChannelDetails:
            last_off_time: int = 0
            volume: int = 0

        channel_details = defaultdict(lambda: ChannelDetails())

        for e in events:
            if e.type == "note_on":
                # First, if we have a pending volume-off event that happens before this note, add it
                if channel_details[e.channel].last_off_time < e.time:
                    yield VolumeEvent(
                        channel_details[e.channel].last_off_time, e.channel, 0
                    )
                    channel_details[e.channel].volume = 0
                yield NoteEvent(e.time, e.channel, e.note)
                # If volume has changed, yield a volume event
                if e.velocity != channel_details[e.channel].volume:
                    yield VolumeEvent(e.time, e.channel, e.velocity)
                    channel_details[e.channel].volume = e.velocity
            elif e.type == "note_off":
                # Don't add a volume-off just yet, we may not have to if another note happens immediately
                channel_details[e.channel].last_off_time = e.time

        for ch, deets in channel_details.items():
            yield VolumeEvent(deets.last_off_time, ch, 0)

    events: list[Event] = sorted(filter_events(events), key=lambda e: e.pcjr_ticks)

    eot = next(e for t in mid.tracks for e in t if e.type == "end_of_track").time

    events.append(WaitEvent(events[-1].pcjr_ticks, eot - events[-1].pcjr_ticks))

    # for e in events:
    #    print(e)

    data, t = [], 0
    for e in events:
        if e.pcjr_ticks > t:
            data.extend(WaitEvent(t, e.pcjr_ticks - t).to_snd())
            t = e.pcjr_ticks
        data.extend(e.to_snd())

    print(", ".join(data))

    return


if __name__ == "__main__":
    cli()
