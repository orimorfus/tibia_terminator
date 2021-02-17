#!/usr/bin/env python3.8

import os
from multiprocessing import Pool
import threading
import queue
import time


MANA_ROW = 3
HP_ROW = MANA_ROW + 1
SPEED_ROW = HP_ROW + 1
MAGIC_SHIELD_ROW = SPEED_ROW + 1
EMERGENCY_ACTION_AMULET_ROW = MAGIC_SHIELD_ROW + 1
EMERGENCY_ACTION_RING_ROW = EMERGENCY_ACTION_AMULET_ROW + 1
EQUIPPED_AMULET_ROW = EMERGENCY_ACTION_RING_ROW + 1
EQUIPPED_RING_ROW = EQUIPPED_AMULET_ROW + 1
MAGIC_SHIELD_STATUS_ROW = EQUIPPED_RING_ROW + 1
DEBUG_ROW = MAGIC_SHIELD_STATUS_ROW + 1


global DEBUG_PPOOL
DEBUG_PPOOL = None
global DEBUG_LEVEL
DEBUG_LEVEL = None

def init_debug_ppool():
    global DEBUG_PPOOL
    if DEBUG_PPOOL is None:
        DEBUG_PPOOL = Pool(processes=3)

def init_debug_level():
    global DEBUG_LEVEL
    if DEBUG_LEVEL is None:
        DEBUG_LEVEL = os.getenv("DEBUG", -1)

def set_debug_level(debug_level):
    global DEBUG_LEVEL
    DEBUG_LEVEL = debug_level

def get_debug_level():
    global DEBUG_LEVEL
    return DEBUG_LEVEL


def debug(msg, debug_level=0):
    if get_debug_level() >= debug_level:
        print(msg)


class StatsEntry():
    def __init__(self, stats, prev_stats, equipment_status,
                 prev_equipment_status):
        self.stats = stats
        self.prev_stats = prev_stats
        self.equipment_status = equipment_status
        self.prev_equipment_status = prev_equipment_status


class LogEntry():
    def __init__(self, msg, row=0, col=0, end='\n'):
        self.msg = msg
        self.row = row
        self.col = col
        self.end = end

# TODO:
#  1. Make this logger a generic logger (CursesLogger) that receives msg, row
#     and col.
#  2. Create layout classes that know where each type of message should be
#     located in the layout (e.g. exec_layout.print_stats(stats, prev_stats,
#     eq_stats, prev_eq_stats), exec_layout.print_title(),
#     exec_layout_.print_debug(...), etc)
#     - The layout classes use this logger to actually print to curses
#  3. Use layout classes depending on the state of the App
#     1. Execution layout
#     2. Choose config layout
#     3. Paused layout? (You get the point)
class StatsLogger(threading.Thread):
    def __init__(self, cliwin):
        super().__init__(daemon=True)
        self.cliwin = cliwin
        self.queue = queue.Queue()
        self.stopped = False

    def log_stats(self, entry):
        self.log(entry)

    def log(self, entry):
        self.queue.put(entry)

    def stop(self):
        self.stopped = True

    def run(self):
        while True:
            if self.queue.qsize() > 0:
                entry = self.queue.get()
                try:
                    if isinstance(entry, StatsEntry):
                        self.print_stats(entry.stats, entry.prev_stats,
                                         entry.equipment_status,
                                         entry.prev_equipment_status)
                    elif isinstance(entry, LogEntry):
                        self.print_entry(entry)
                finally:
                    self.queue.task_done()
            elif self.stopped:
                break
            else:
                # sleep 10 ms
                time.sleep(0.01)

    def print_stats(self, stats, prev_stats, equipment_status,
                    prev_equipment_status):
        mana = stats['mana']
        hp = stats['hp']
        speed = stats['speed']
        magic_shield_level = stats['magic_shield']
        emergency_action_amulet = equipment_status['emergency_action_amulet']
        emergency_action_ring = equipment_status['emergency_action_ring']
        equipped_ring = equipment_status['equipped_ring']
        equipped_amulet = equipment_status['equipped_amulet']
        magic_shield_status = equipment_status['magic_shield_status']

        self.winprint(f"Mana: {str(mana)}", MANA_ROW)
        self.winprint(f"HP: {str(hp)}", HP_ROW)
        self.winprint(f"Speed: {str(speed)}", SPEED_ROW)
        self.winprint(f"Magic Shield: {str(magic_shield_level)}",
                      MAGIC_SHIELD_ROW)
        self.winprint(
            f"Emergency Action Amulet: {emergency_action_amulet}",
              EMERGENCY_ACTION_AMULET_ROW)
        self.winprint(f"Emergency Action Ring: {emergency_action_ring}",
                        EMERGENCY_ACTION_RING_ROW)
        self.winprint(f"Equipped Amulet: {equipped_amulet}",
                        EQUIPPED_AMULET_ROW)
        self.winprint(f"Equipped Ring: {equipped_ring}",
                        EQUIPPED_RING_ROW)
        self.winprint(f"Magic Shield Status: {magic_shield_status}",
                        MAGIC_SHIELD_STATUS_ROW)

        # self.winprint(f"Debug self.char_keeper.equipment_keeper.prev_mode:
        #                 {self.char_keeper.equipment_keeper.prev_mode}",
        #                DEBUG_ROW)

    def print_entry(self, entry):
        self.winprint(entry.msg, entry.row, entry.col, entry.end)

    def winprint(self, msg, row=0, col=0, end='\n'):
        self.cliwin.addstr(row, col, msg + end)
        self.cliwin.refresh()

if __name__ != "__main__":
    init_debug_ppool()
    init_debug_level()
