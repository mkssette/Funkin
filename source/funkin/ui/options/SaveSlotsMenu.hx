package funkin.ui.options;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.InitState;
import funkin.assets.Paths;
import funkin.audio.FunkinSound;
import funkin.save.Save;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.Page;
import funkin.ui.Prompt;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.util.Constants;

/**
 * Menu page displaying the list of dynamically detected Funkin#.sol save slots.
 * Selecting any slot opens its dedicated options (Load, Copy, Delete).
 * Slot 1 is always protected and can never be deleted or overwritten.
 */
class SaveSlotsMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var items:TextMenuList;
  var statusText:FlxText;
  var prompt:Null<Prompt> = null;

  var inSlotListMode:Bool = true;
  var currentSlotSelected:Int = Constants.BASE_SAVE_SLOT;

  public function new()
  {
    super();

    statusText = new FlxText(0, 15, FlxG.width, '', 20);
    statusText.setFormat(Paths.font('ui/fonts/VCR OSD Mono'), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    statusText.borderSize = 1.5;
    add(statusText);

    buildSlotsListPage();
  }

  override function set_exists(value:Bool):Bool
  {
    if (value && !exists)
    {
      buildSlotsListPage();
    }
    return super.set_exists(value);
  }

  function resetItemsList():Void
  {
    if (items != null)
    {
      remove(items);
      items.destroy();
    }
    add(items = new TextMenuList());
  }

  /**
   * Rebuilds the dynamic list of slots based on Funkin#.sol files found in the save folder.
   */
  public function buildSlotsListPage():Void
  {
    inSlotListMode = true;
    resetItemsList();

    var existingSlots:Array<Int> = Save.getExistingSlots();

    statusText.text = 'ACTIVE: ' + Save.getSlotName(Save.currentSlot) + '   |   TOTAL SLOTS: ' + existingSlots.length + '\n< SELECT A SLOT TO VIEW OPTIONS >';

    for (i in 0...existingSlots.length)
    {
      var slot:Int = existingSlots[i];
      var label:String = getSlotDisplayLabel(slot);

      var item:TextMenuItem = items.createItem(0, 50 + i * 50, label, AtlasFont.DEFAULT, () -> openSlotActions(slot));
      item.screenCenter(X);
    }

    var nextAvailable:Int = Save.getNextAvailableSlot();
    var createLabel:String = 'CREATE NEW SLOT (SLOT ' + nextAvailable + ')';

    var createY:Float = 55 + existingSlots.length * 50;
    var createItem:TextMenuItem = items.createItem(0, createY, createLabel, AtlasFont.DEFAULT, onPromptCreateNewSlot);
    createItem.screenCenter(X);

    var backItem:TextMenuItem = items.createItem(0, createY + 55, "BACK", AtlasFont.BOLD, exit);
    backItem.screenCenter(X);

    items.selectItem(0);
  }

  function getSlotDisplayLabel(slot:Int):String
  {
    var isOriginal:Bool = (slot == Constants.BASE_SAVE_SLOT);
    var isActive:Bool = (slot == Save.currentSlot);
    var hasData:Bool = Save.hasSlotData(slot);

    var base:String = isOriginal ? 'SLOT 1 - ORIGINAL' : 'SLOT ' + slot;

    if (isActive) return base + ' (ACTIVE)';
    if (hasData) return base + ' (SAVED)';
    return base + ' (EMPTY)';
  }

  /**
   * Opens the options for a selected slot (Load, Copy, Delete, Back).
   */
  function openSlotActions(slot:Int):Void
  {
    inSlotListMode = false;
    currentSlotSelected = slot;
    resetItemsList();

    var slotName:String = Save.getSlotName(slot);
    var summary:String = Save.getSlotSummary(slot);
    var isOriginal:Bool = (slot == Constants.BASE_SAVE_SLOT);
    var isActive:Bool = (slot == Save.currentSlot);

    statusText.text = 'OPTIONS FOR: ' + slotName + ' (' + summary + ')' + (isOriginal ? '\n[ORIGINAL SLOT - PROTECTED]' : '');

    var currentY:Float = 120;

    // Option 1: Load Slot
    var loadItem:TextMenuItem = items.createItem(0, currentY, "LOAD THIS SLOT", AtlasFont.BOLD, function()
    {
      if (isActive)
      {
        openConfirmPrompt("Slot " + slot + " is already active.", "OK", () -> {});
        return;
      }

      openConfirmPrompt("Switch to " + slotName + "?\nThe game will reload.", "Load", function()
      {
        Save.switchSlot(slot);
        FlxG.switchState(() -> new InitState());
      });
    });
    loadItem.screenCenter(X);
    currentY += 70;

    // Option 2: Copy Active into this slot (Only for slots other than slot 1, since original cannot be overwritten)
    if (!isOriginal)
    {
      var copyItem:TextMenuItem = items.createItem(0, currentY, "COPY ACTIVE INTO THIS SLOT", AtlasFont.BOLD, function()
      {
        if (slot == Save.currentSlot)
        {
          openConfirmPrompt("Cannot copy active slot into itself.", "OK", () -> {});
          return;
        }

        var activeName:String = Save.getSlotName(Save.currentSlot);
        openConfirmPrompt("Overwrite " + slotName + "\nwith " + activeName + " data?\nAre you sure?", "Copy", function()
        {
          Save.copySlot(Save.currentSlot, slot);
          openSlotActions(slot);
        });
      });
      copyItem.screenCenter(X);
      currentY += 70;

      // Option 3: Delete this slot (Only for slots other than slot 1, since original cannot be deleted)
      var deleteItem:TextMenuItem = items.createItem(0, currentY, "DELETE THIS SLOT", AtlasFont.BOLD, function()
      {
        openConfirmPrompt("Permanently delete " + slotName + "\nfrom disk (Funkin" + slot + ".sol)?\nThis cannot be undone!", "Delete", function()
        {
          Save.deleteSlot(slot);
          buildSlotsListPage();
        });
      });
      deleteItem.screenCenter(X);
      currentY += 70;
    }

    // Option: Back to Slots List
    var backItem:TextMenuItem = items.createItem(0, currentY, "BACK TO SLOTS", AtlasFont.BOLD, buildSlotsListPage);
    backItem.screenCenter(X);

    items.selectItem(0);
  }

  function onPromptCreateNewSlot():Void
  {
    var nextSlot:Int = Save.getNextAvailableSlot();
    openConfirmPrompt("Create new save Slot " + nextSlot + "\non disk (Funkin" + nextSlot + ".sol)?", "Create", function()
    {
      var created:Int = Save.createNewSlot();
      openSlotActions(created);
    });
  }

  override function update(elapsed:Float):Void
  {
    enabled = (prompt == null);
    super.update(elapsed);
  }

  override function updateEnabled(elapsed:Float):Void
  {
    if (!controls.BACK_P) return;

    if (!inSlotListMode)
    {
      buildSlotsListPage();
      return;
    }

    exit();
  }

  override function set_enabled(value:Bool):Bool
  {
    if (items != null) items.enabled = value;
    return super.set_enabled(value);
  }

  function openConfirmPrompt(text:String, yesText:String, onYes:Void->Void, ?groupToOpenOn:Null<FlxGroup>):Void
  {
    if (prompt != null) return;

    prompt = new Prompt(text, Custom(yesText, "Cancel"), AtlasFont.DEFAULT);
    prompt.create();
    prompt.createBgFromMargin(100, 0xFFFAFD6D);
    prompt.back.scrollFactor.set(0, 0);
    FlxG.state.add(prompt);
    codex.currentPage.enabled = false;

    final closePrompt:() -> Void = () ->
    {
      codex.currentPage.enabled = true;
      prompt.close();
      prompt.destroy();
      prompt = null;
    };

    prompt.onYes = function()
    {
      onYes();
      closePrompt();
    };

    prompt.onNo = closePrompt;
  }
}
