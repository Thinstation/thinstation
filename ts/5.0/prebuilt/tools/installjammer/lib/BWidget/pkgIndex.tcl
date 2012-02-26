if {[catch {package require Tcl}]} return
package ifneeded BWidget 2.0 "\
    package require Tk 8.4;\
    [list tclPkgSetup $dir BWidget 2.0 {
{arrow.tcl source {ArrowButton ArrowButton::create ArrowButton::use}}
{bitmap.tcl source {Bitmap::get Bitmap::use}}
{button.tcl source {Button Button::create Button::use}}
{buttonbox.tcl source {ButtonBox ButtonBox::create ButtonBox::use}}
{calendar.tcl source {Calendar Calendar::create Calendar::use}}
{choosedir.tcl source {ChooseDirectory ChooseDirectory::create ChooseDirectory::use}}
{choosefile.tcl source {ChooseFile ChooseFile::create ChooseFile::use}}
{color.tcl source {SelectColor SelectColor::menu SelectColor::dialog SelectColor::setcolor}}
{combobox.tcl source {ComboBox ComboBox::create ComboBox::use}}
{dialog.tcl source {Dialog Dialog::create Dialog::use}}
{dragsite.tcl source {DragSite::register DragSite::include DragSite::use}}
{drawerpanel.tcl source {DrawerPanel DrawerPanel::create DrawerPanel::use}}
{dropsite.tcl source {DropSite::register DropSite::include DropSite::use}}
{dynhelp.tcl source {DynamicHelp::configure DynamicHelp::use DynamicHelp::register DynamicHelp::include DynamicHelp::add DynamicHelp::delete}}
{entry.tcl source {Entry Entry::create Entry::use}}
{font.tcl source {SelectFont SelectFont::create SelectFont::use SelectFont::loadfont}}
{icons.tcl source {IconLibrary IconLibrary::create IconLibrary::use}}
{label.tcl source {Label Label::create Label::use}}
{labelentry.tcl source {LabelEntry LabelEntry::create LabelEntry::use}}
{labelframe.tcl source {LabelFrame LabelFrame::create LabelFrame::use}}
{listbox.tcl source {ListBox ListBox::create ListBox::use}}
{mainframe.tcl source {MainFrame MainFrame::create MainFrame::use}}
{messagedlg.tcl source {MessageDlg MessageDlg::create MessageDlg::use}}
{notebook.tcl source {NoteBook NoteBook::create NoteBook::use}}
{optiontree.tcl source {OptionTree OptionTree::create OptionTree::use}}
{pagesmgr.tcl source {PagesManager PagesManager::create PagesManager::use}}
{panedw.tcl source {PanedWindow PanedWindow::create PanedWindow::use}}
{panelframe.tcl source {PanelFrame PanelFrame::create PanelFrame::use}}
{passwddlg.tcl source {PasswdDlg PasswdDlg::create PasswdDlg::use}}
{preferences.tcl source {Preferences Preferences::create Preferences::use}}
{progressbar.tcl source {ProgressBar ProgressBar::create ProgressBar::use}}
{progressdlg.tcl source {ProgressDlg ProgressDlg::create ProgressDlg::use}}
{properties.tcl source {Properties Properties::create Properties::use}}
{scrollframe.tcl source {ScrollableFrame ScrollableFrame::create ScrollableFrame::use}}
{scrollview.tcl source {ScrollView ScrollView::create ScrollView::use}}
{scrollw.tcl source {ScrolledWindow ScrolledWindow::create ScrolledWindow::use}}
{separator.tcl source {Separator Separator::create Separator::use}}
{spinbox.tcl source {SpinBox SpinBox::create SpinBox::use}}
{splitlist.tcl source {SplitList SplitList::create SplitList::use}}
{statusbar.tcl source {StatusBar StatusBar::create StatusBar::use}}
{stddialog.tcl source {StandardDialog StandardDialog::create StandardDialog::use}}
{tablelist.tcl source {TableList TableList::create TableList::use}}
{text.tcl source {Text Text::create Text::use}}
{titleframe.tcl source {TitleFrame TitleFrame::create TitleFrame::use}}
{tree.tcl source {Tree Tree::create Tree::use}}
{ttkbutton.tcl source {TTKButton TTKButton::create TTKButton::use}}
{wizard.tcl source {Wizard Wizard::create Wizard::use SimpleWizard ClassicWizard}}
{xpm2image.tcl source {xpm-to-image}}

}]; \
	[list namespace eval ::BWIDGET {}]; \
	[list set ::BWIDGET::LIBRARY $dir]; \
    [list source [file join $dir widget.tcl]]; \
    [list source [file join $dir init.tcl]]; \
    [list source [file join $dir utils.tcl]]; \
    BWidget::use
"
