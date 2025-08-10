
import os
import sys
import ast
import time
import ctypes
import shutil
import getpass
import subprocess
from rich.text import Text
from rich.align import Align
from rich.table import Table
from rich.console import Console
from protect import encrypt_string, decrypt_string


console = Console()
platform = sys.platform

# Set base_dir based on platform for storing .managervault
if platform == "win32":
    base_dir = os.path.join(os.environ["APPDATA"], "Hardlock")
    os.makedirs(base_dir, exist_ok=True)
else:
    base_dir = os.path.dirname(sys.executable)
os.chdir(base_dir)

manager_path = os.path.join(base_dir, ".managervault")


def secure_vault(vault_path):
    if not os.path.exists(vault_path):
        with open(vault_path, "wb") as f:
            f.write(b"")
    username = getpass.getuser()
    user_domain = os.environ.get("USERDOMAIN")
    if user_domain and user_domain.upper() != os.environ.get("COMPUTERNAME", "").upper():
        user_spec = f"{user_domain}\{username}"
    else:
        user_spec = username
    subprocess.run([
        "icacls", vault_path,
        "/inheritance:r",
        "/grant:r",
        f"Administrators:F",
        f"{user_spec}:F",
        "/c"
    ], check=True, shell=False)


def lock_file(password):
    with open(manager_path, "r") as file:
        contents = file.read()
        enc = encrypt_string(password, contents)
    with open(manager_path, "w") as file:
        file.write(enc)


def decrypt(password):
    with open(manager_path, "r") as file:
        key = file.read()
        unlock = decrypt_string(password, key)
    with open(manager_path, "w") as file:
        key = file.write(unlock)


def center_print(content: str):
    columns = shutil.get_terminal_size().columns
    rich_text = Text.from_markup(content)
    aligned = Align(rich_text, align="center", width=columns)
    console.print(aligned)


def center_input(prompt: str = "❯ "):
    columns = shutil.get_terminal_size().columns
    line_width = 52
    left_edge = (columns // 2) - (line_width // 2)
    cursor_pos = left_edge + 1
    padded_prompt = " " * cursor_pos + prompt
    return input(padded_prompt)


def banner():
    print(manager_path)
    text1 = Text(r"                      _   __            _    ")
    text2 = Text(r"   /\  /\__ _ _ __ __| | / /  ___   ___| | __")
    text3 = Text(r"  / /_/ / _` | '__/ _` |/ /  / _ \ / __| |/ /")
    text4 = Text(r" / __  / (_| | | | (_| / /__| (_) | (__|   < ")
    text5 = Text(r" \/ /_/ \__,_|_|  \__,_\____/\___/ \___|_|\_\\")
    text6 = Text("-"*47)
    console.print(Align(text1, align="center"))
    console.print(Align(text2, align="center"))
    console.print(Align(text3, align="center"))
    console.print(Align(text4, align="center"))
    console.print(Align(text5, align="center"))
    console.print(Align(text6, align="center"))


def check_empty():
    if os.path.exists(manager_path):
        with open(manager_path, "r") as file:
            contents = file.read()
            if len(contents.strip()) == 0:
                return "EMPTY_MANAGER"
    else:
        with open(manager_path, "w") as file:
            pass
        return "EMPTY_MANAGER"


def lock_screen():
    global master_password
    print("\033c")
    output = check_empty()
    if output == "EMPTY_MANAGER":
        return
    banner()
    center_print(
        "Please enter Master Password [green]'Ctrl + C to exit'[/green]")
    attempts = 0
    while True:
        try:
            master_password = center_input()
            decrypt(master_password)
            center_print("[green]Decrypting...[/green]")
            break
        except KeyboardInterrupt:
            sys.exit()
        except Exception:
            if attempts < 3:
                attempts += 1
                center_print("[red]Incorrect Password try again[/red]")
                continue
            else:
                center_print("[red]Too many failed attempts ...[/red]")
                sys.exit()
    print("\033c")


def manager_table():
    global manager
    entry_number = 0
    with open(manager_path, "r") as file:
        data = file.read()
    manager = ast.literal_eval(data)
    table = Table(title="Password Manager")
    table.add_column(Text("Username", justify="center"), justify="left")
    table.add_column("Password", justify="center")
    for index, (username, password) in manager.items():
        entry_number += 1
        if username == "BLANKUSERNAMEENTRY":
            table.add_row(f"{entry_number}. ---------", password)
        elif password == "BLANKPASSWORDENTRY":
            table.add_row(f"{entry_number}. {username}", "----------")
        else:
            table.add_row(f"{entry_number}. {username}", password)
    return table


def manager_add():
    coloums = shutil.get_terminal_size().columns
    try:
        print("0\33c")
        banner()
        if check == "EMPTY_MANAGER":
            center_print(
                "[green]Hardlock Vault has not been created yet...[/green]")
            center_print("[green]Add a entry to create a vault![/green]")
        else:
            console.print(
                Align(manager_table(), align="center", width=coloums))
        center_print(
            "what [underline]username[/underline] would you like to add? [green]'Ctrl + C to cancel'[/green]")
        add_user = center_input()
        center_print(
            "what [underline]password[/underline] would you like to add? [green]'Ctrl + C to cancel'[/green]")
        add_pwd = center_input()
        if len(add_user.strip()) == 0:
            add_user = "BLANKUSERNAMEENTRY"
        if len(add_pwd.strip()) == 0:
            add_pwd = "BLANKPASSWORDENTRY"
        if len(add_user.strip()) == 0 and len(add_pwd.strip()) == 0:
            center_print(
                "[yellow]Nothing to add returning to main menu...[/yellow]")
            time.sleep(2)
            raise KeyboardInterrupt
        if check == "EMPTY_MANAGER":
            starting_index = 1
            full_entry = {starting_index: (add_user, add_pwd)}
            with open(manager_path, "w") as file:
                file.write(str(full_entry))
            center_print(
                "What would you like your [underline]new password[/underline] to be for hardlock?")
            center_print(
                "[yellow]For safety reasons you will be logged out after[/yellow]")
            new_master = center_input()
            print("\033c")
            banner()
            center_print("[green]Hardlock database has been created!![/green]")
            center_print("[green]Relogin with newly created password[/green]")
            lock_file(new_master)
            if platform == "linux":
                os.system(f"sudo chown root:root {manager_path}")
                os.system(f"sudo chmod 600 {manager_path}")
                sys.exit()
            elif platform == "win32":
                secure_vault(manager_path)
                sys.exit()
        else:
            if bool(manager) is False:
                new_index = 1
            else:
                new_index = max(manager.keys()) + 1
            full_entry = {new_index: (add_user, add_pwd)}
            manager.update(full_entry)
            with open(manager_path, "w") as file:
                file.write(str(manager))
            return
    except KeyboardInterrupt:
        print("\033c")
        return


def manager_remove():
    coloums = shutil.get_terminal_size().columns
    try:
        if check == "EMPTY_MANAGER" or bool(manager) is False:
            center_print("[yellow]No entries to remove[/yellow]")
            time.sleep(1)
            return
        print("\033c")
        manager_keys = manager.keys()
        banner()
        console.print(Align(manager_table(), align="center", width=coloums))
        center_print(
            "what entry [underline]row index[/underline] would you like to [underline]remove[/underline]")
        while True:
            number_index = int(center_input())
            if number_index in manager_keys:
                usr, pwd = manager[number_index]
                if usr == "BLANKUSERNAMEENTRY":
                    center_print(
                        f"row number {number_index} contains: [bold]----------  {pwd}[/bold]")
                elif pwd == "BLANKPASSWORDENTRY":
                    center_print(f"row number {number_index} contains: [bold]{usr}  ----------[/bold]")
                else:
                    center_print(f"row number {number_index} contains: [bold]{usr}  {pwd}[/bold]")
                center_print("are you sure you want to delete? y/n")
                while True:
                    sure = center_input().lower()
                    if sure == "y":
                        break
                    elif sure == "n":
                        return
                    else:
                        center_print("[yellow]y or n options only[/yellow]")
                if max(manager.keys()) == number_index:
                    manager.pop(number_index)
                    with open(manager_path, "w") as file:
                        file.write(str(manager))
                else:
                    new_manager = {
                        (i - 1 if i > number_index else i): (user, pwd)
                        for i, (user, pwd) in manager.items()
                        if i != number_index
                    }
                    with open(manager_path, "w") as file:
                        file.write(str(new_manager))
                return
            else:
                center_print(f"[yellow]Not a valid row number '{number_index}' [/yellow]")
    except KeyboardInterrupt:
        print("\033c")
        return


def manager_edit():
    global check
    coloums = shutil.get_terminal_size().columns
    check = check_empty()
    if check == "EMPTY_MANAGER" or bool(manager) is False:
        center_print("[yellow]No entries to edit[/yellow]")
        time.sleep(1)
        return
    try:
        print("\033c")
        banner()
        console.print(Align(manager_table(), align="center", width=coloums))
        manager_keys = manager.keys()
        center_print(
            "What [underline]row index[/underline] would you like to [underline]edit?[/underline]")
        while True:
            index = int(center_input())
            if index in manager_keys:
                break
            else:
                center_print(f"[yellow]Not a valid row index '{index}'[/yellow]")
                continue
        cuser, cpass = manager[index]
        center_print(
            f"What [bold]Username[/bold] would you like to replace [bold]{cuser}[/bold]")
        center_print(
            "[green]Input nothing to skip or type 'delete' to remove[/green]")
        new_user = center_input()
        center_print(
            f"What [bold]Password[/bold] would you like to replace [bold]{cpass}[/bold]")
        new_pass = center_input()
        if new_user.strip() == "":
            new_user = cuser
        elif new_user.lower().strip() == "delete":
            new_user = "-"*10
        if new_pass.strip() == "":
            new_pass = cpass
        elif new_pass.lower().strip() == "delete":
            new_pass = "-"*10
        if new_user == cuser and new_pass == cpass:
            center_print(
                "[yellow]No entries to edit returning to main menu...[/yellow]")
            time.sleep(2)
            raise KeyboardInterrupt
        center_print(
            f"[bold]{new_user}  {new_pass}[/bold] will replace [bold]{cuser} {cpass}[/bold]")
        center_print("Are these changes fine? y/n")
        while True:
            sure = center_input()
            if sure.lower() == "y":
                break
            elif sure.lower() == "n":
                center_print(
                    "[yellow]Aborting editing, retunring to main menu...[/yellow]")
                time.sleep(2)
                print("\033c")
                return
        with open(manager_path, "w") as file:
            if new_user.strip() == "-"*10:
                new_user = "BLANKUSERNAMEENTRY"
            elif new_pass.strip() == "-"*10:
                new_pass = "BLANKPASSWORDENTRY"
            full_entry = {index: (new_user, new_pass)}
            manager.update(full_entry)
            file.write(str(manager))
            return
    except KeyboardInterrupt:
        print("\033c")
        return


def change_manager_password():
    if check == "EMPTY_MANAGER" or bool(manager) is False:
        center_print(
            "[yellow]Hardlock is empty no current password required[/yellow]")
        time.sleep(1)
        return
    try:
        print("\033c")
        attempts = 0
        banner()
        center_print(
            "Please type your [underline]master key[/underline] to change password")
        while True:
            current_master = center_input()
            if current_master == master_password:
                break
            else:
                attempts += 1
                center_print(f"[red]Invalid password {current_master}[/red]")
            if attempts == 3:
                center_print(
                    "[red]Too many failed attempts locking manager...[/red]")
                lock_file(master_password)
                sys.exit()
        center_print(
            "what would you like your [underline]new[/underline] master key to be?")
        new_master = center_input()
        center_print("Retype password for varification")
        while True:
            verify_master = center_input()
            if verify_master == new_master:
                break
            else:
                center_print(
                    "[yellow]Passwords do not match try again[/yellow]")
                continue
        print("\033c")
        banner()
        center_print("Changing password...")
        center_print("[green]Password has been changed![/green]")
        center_print("[green]Log into Hardlock with new password[/green]")
        lock_file(verify_master)
        sys.exit()
    except KeyboardInterrupt:
        print("\033c")
        return


def editor_logic():
    global check
    coloums = shutil.get_terminal_size().columns
    check = check_empty()
    while True:
        banner()
        if check == "EMPTY_MANAGER":
            center_print(
                "[green]No entries are in Hardlock, Add some![/green]")
        else:
            console.print(
                Align(manager_table(), align="center", width=coloums))
        center_print(
            "[1]Add Entry    [2]Remove Entry     [3]Edit Entry   [99]Change Password")
        center_print(" "*34 + '[green]Ctrl + C to exit[/green]' + " "*34)
        edit_option = center_input().lower()
        if edit_option == "1" or edit_option.lower() == "add entry":
            manager_add()
            print("0\33c")
            continue
        elif edit_option == "2" or edit_option.lower() == "remove entry":
            manager_remove()
            print("0\33c")
            continue
        elif edit_option == "3" or edit_option.lower() == "edit entry":
            manager_edit()
            print("0\33c")
            continue
        elif edit_option == "99" or edit_option.lower() == "change password":
            change_manager_password()
            print("0\33c")
            continue
        elif edit_option.lower() == "exit":
            return
        else:
            center_print(f"[red]Not a valid option {edit_option}[/red]")
            time.sleep(1)
            print("0\33c")


def main():
    try:
        check_empty()
        lock_screen()
        editor_logic()
    except KeyboardInterrupt:
        return


if __name__ == "__main__":
    main()
    try:
        lock_file(master_password)
    except NameError:
        sys.exit()
