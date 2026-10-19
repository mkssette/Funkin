package funkin.ui.options;

import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.assets.Paths;
import funkin.audio.FunkinSound;
import funkin.save.Save;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.Page;
import funkin.ui.Prompt;
import funkin.ui.TextMenuList;
import funkin.ui.TextMenuList.TextMenuItem;
import funkin.util.Constants;
#if FEATURE_NEWGROUNDS
import funkin.api.newgrounds.NewgroundsClient;
import funkin.api.newgrounds.NGSaveSlot;
#end

class SaveDataMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var items:TextMenuList;
  var statusText:FlxText;
  var prompt:Null<Prompt> = null;

  public function new()
  {
    super();

    statusText = new FlxText(0, 40, FlxG.width, '', 22);
    statusText.setFormat(Paths.font('ui/fonts/VCR OSD Mono'), 22, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
    statusText.borderSize = 1.5;
    add(statusText);

    add(items = new TextMenuList());

    createItem("MANAGE SAVE SLOTS", () -> codex.switchPage(SaveSlots));

    createItem("CLEAR ACTIVE SAVE DATA", openSaveDataPrompt);

    #if FEATURE_NEWGROUNDS
    if (NewgroundsClient.instance.isLoggedIn())
    {
      createItem("LOAD FROM NG", function()
      {
        openConfirmPrompt(
          "This will overwrite
        \nactive save data.
        \nAre you sure?",
          "Overwrite",
          () -> Save.loadFromNewgrounds(() -> FlxG.switchState(() -> new funkin.InitState()))
        );
      });

      createItem("SAVE TO NG", function()
      {
        openConfirmPrompt("This will overwrite
        \nALL save data saved
        \non NG. Are you sure?", "Overwrite", function()
        {
          Save.saveToNewgrounds();
        });
      });

      createItem("CLEAR NG SAVE DATA", function()
      {
        openConfirmPrompt("This will delete
        \nALL save data saved
        \non NG. Are you sure?", "Delete", function()
        {
          NGSaveSlot.instance.clear();
        });
      });
    }
    #end

    createItem("EXIT", exit);

    refreshStatusText();
  }

  function refreshStatusText():Void
  {
    var activeName:String = Save.getSlotName(Save.currentSlot);
    var summary:String = Save.getSlotSummary(Save.currentSlot);
    statusText.text = 'ACTIVE SAVE: ' + activeName + ' (' + summary + ')';
  }

  function createItem(name:String, callback:Void->Void, fireInstantly:Bool = false):TextMenuItem
  {
    var item:TextMenuItem = items.createItem(0, 110 + items.length * 85, name, AtlasFont.BOLD, callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    return item;
  }

  override function update(elapsed:Float):Void
  {
    enabled = (prompt == null);
    super.update(elapsed);
    refreshStatusText();
  }

  override function set_enabled(value:Bool):Bool
  {
    items.enabled = value;
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

  public function openSaveDataPrompt():Void
  {
    if (Save.currentSlot == Constants.BASE_SAVE_SLOT)
    {
      openConfirmPrompt("Slot 1 is the original save
        \nand cannot be deleted.", "OK", () -> {});
      return;
    }

    openConfirmPrompt("This will delete
        \nALL data in Slot " + Save.currentSlot + ".
        \nAre you sure?
      ", "Delete", function()
    {
      Save.clearData();
      FlxG.switchState(() -> new funkin.InitState());
    });
  }

  public function hasMultipleOptions():Bool
  {
    return true;
  }
}
