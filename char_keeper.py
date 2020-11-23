"""Keeps the character healthy in every way."""

from char_status import CharStatus
from equipment_keeper import EquipmentKeeper
from hp_keeper import HpKeeper
from magic_shield_keeper import MagicShieldKeeper
from mana_keeper import ManaKeeper
from speed_keeper import SpeedKeeper


class CharKeeper:
    def __init__(self, client, char_config, mana_keeper=None, hp_keeper=None,
                 speed_keeper=None, equipment_keeper=None,
                 magic_shield_keeper=None):
        self.client = client
        self.char_config = char_config
        self.init_mana_keeper(client, char_config, mana_keeper)
        self.init_hp_keeper(client, char_config, hp_keeper)
        self.init_speed_keeper(client, char_config, speed_keeper)
        self.init_equipment_keeper(client, char_config, equipment_keeper)
        self.init_magic_shield_keeper(client, char_config, magic_shield_keeper)

    def init_mana_keeper(self, client, char_config, mana_keeper=None):
        if mana_keeper is None:
            self.mana_keeper = ManaKeeper(
                client, char_config['mana_hi'],
                char_config['mana_lo'], char_config['critical_mana'],
                char_config['downtime_mana'], char_config['total_mana'])
        else:
            self.mana_keeper = mana_keeper

    def init_hp_keeper(self, client, char_config, hp_keeper=None):
        if hp_keeper is None:
            self.hp_keeper = HpKeeper(
                client, char_config['total_hp'],
                char_config['heal_at_missing'], char_config['exura_heal'],
                char_config['exura_gran_heal'],
                char_config['downtime_heal_at_missing'])
        else:
            self.hp_keeper = hp_keeper

    def init_speed_keeper(self, client, char_config, speed_keeper=None):
        if speed_keeper is None:
            self.speed_keeper = SpeedKeeper(
                client,
                char_config['base_speed'],
                char_config['hasted_speed'])
        else:
            self.speed_keeper = speed_keeper

    def init_equipment_keeper(self, client, char_config,
                              equipment_keeper=None):
        if equipment_keeper is None:
            self.equipment_keeper = EquipmentKeeper(
                client,
                char_config['should_equip_amulet'],
                char_config['should_equip_ring'],
                char_config['should_eat_food'],
                char_config.get('equip_amulet_secs', 1),
                char_config.get('equip_ring_secs', 1))
        else:
            self.equipment_keeper = equipment_keeper

    def init_magic_shield_keeper(self, client, char_config, magic_shield_keeper=None):
        if char_config.get('should_cast_magic_shield', False):
            self.magic_shield_keeper = NoopKeeper()
        elif magic_shield_keeper is None:
            self.magic_shield_keeper = MagicShieldKeeper(client)
        else:
            self.magic_shield_keeper = magic_shield_keeper

    def handle_hp_change(self, hp, speed, mana):
        is_downtime = self.speed_keeper.is_hasted(speed) and \
            self.mana_keeper.is_healthy_mana(mana)

        self.hp_keeper.handle_status_change(
            CharStatus(hp, speed, mana),
            is_downtime)

    def handle_mana_change(self, hp, speed, mana):
        char_status = CharStatus(hp, speed, mana)
        if self.should_skip_drinking_mana(char_status):
            return False

        is_downtime = self.hp_keeper.is_healthy_hp(hp) and \
            self.speed_keeper.is_hasted(speed)
        self.mana_keeper.handle_status_change(char_status, is_downtime)

    def should_skip_drinking_mana(self, char_status):
        # Do not issue order to use mana potion if we're at critical HP levels,
        # unless we're at critical mana levels in order to avoid delaying
        # heals.
        if self.hp_keeper.is_critical_hp(char_status.hp) and \
           not self.mana_keeper.is_critical_mana(char_status.mana):
            return True

        # Do not issue order to use mana potion if we are paralyzed unless
        # we're at critical mana levels, in order to avoid delaying haste.
        if self.speed_keeper.is_paralized(char_status.speed) and \
           not self.mana_keeper.is_critical_mana(char_status.mana):
            return True

        return False

    def handle_speed_change(self, hp, speed, mana):
        char_status = CharStatus(hp, speed, mana)
        if self.should_skip_haste(char_status):
            return False
        self.speed_keeper.handle_status_change(char_status)

    def should_skip_haste(self, char_status):
        # Do not issue order to haste if we're at critical HP levels.
        if self.hp_keeper.is_critical_hp(char_status.hp):
            return True

        # Do not issue a haste order if we're not paralyzed and we're at
        # critical mana levels.
        if self.mana_keeper.is_critical_mana(char_status.mana) and \
           not self.speed_keeper.is_paralized(char_status.speed):
            return True
        else:
            return False

    def handle_equipment(self, hp, speed, mana, is_amulet_slot_empty=False,
                         is_ring_slot_empty=False):
        char_status = CharStatus(
            hp, speed, mana, is_amulet_slot_empty, is_ring_slot_empty)
        self.magic_shield_keeper.handle_status_change(char_status)
        self.equipment_keeper.handle_status_change(char_status)

class NoopKeeper:
    def handle_status_change(self, char_status):
        pass