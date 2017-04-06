/*
 * Author: Paul Reioux aka Faux123 <reioux@gmail.com>
 *
 * Copyright 2013 Paul Reioux
 * Copyright 2012 Paul Reioux
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation, and
 * may be copied, distributed, and modified under those terms.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Avsky: lcd_notify adjustments,
 * function names should be changed as well. Maybe some day.
 */

#include <linux/module.h>
#include <linux/kobject.h>
#include <linux/sysfs.h>
#include <linux/lcd_notify.h>
#include <linux/mutex.h>
#include <linux/notifier.h>
#include <linux/reboot.h>
#include <linux/writeback.h>

#define DYN_FSYNC_VERSION_MAJOR 2
#define DYN_FSYNC_VERSION_MINOR 0

static DEFINE_MUTEX(fsync_mutex);

bool lcd_notify_suspend_active __read_mostly = false;
bool dyn_fsync_active __read_mostly = true;

struct notifier_block lcd_worker_dyn_fsync;

static ssize_t dyn_fsync_active_show(struct kobject *kobj,
		struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "%u\n", (dyn_fsync_active ? 1 : 0));
}

static ssize_t dyn_fsync_active_store(struct kobject *kobj,
		struct kobj_attribute *attr, const char *buf, size_t count)
{
	unsigned int data;

	if(sscanf(buf, "%u\n", &data) == 1) {
		if (data == 1) {
			pr_info("%s: dynamic fsync enabled\n", __FUNCTION__);
			dyn_fsync_active = true;
		}
		else if (data == 0) {
			pr_info("%s: dyanamic fsync disabled\n", __FUNCTION__);
			dyn_fsync_active = false;
		}
		else
			pr_info("%s: bad value: %u\n", __FUNCTION__, data);
	} else
		pr_info("%s: unknown input!\n", __FUNCTION__);

	return count;
}

static ssize_t dyn_fsync_version_show(struct kobject *kobj,
		struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "version: %u.%u\n",
		DYN_FSYNC_VERSION_MAJOR,
		DYN_FSYNC_VERSION_MINOR);
}

static ssize_t dyn_fsync_powersuspend_show(struct kobject *kobj,
		struct kobj_attribute *attr, char *buf)
{
	return sprintf(buf, "lcd_notify suspend active: %u\n", lcd_notify_suspend_active);
}

static struct kobj_attribute dyn_fsync_active_attribute = 
	__ATTR(Dyn_fsync_active, 0666,
		dyn_fsync_active_show,
		dyn_fsync_active_store);

static struct kobj_attribute dyn_fsync_version_attribute = 
	__ATTR(Dyn_fsync_version, 0444, dyn_fsync_version_show, NULL);

static struct kobj_attribute dyn_fsync_powersuspend_attribute = 
	__ATTR(Dyn_fsync_powersuspend, 0444, dyn_fsync_powersuspend_show, NULL);

static struct attribute *dyn_fsync_active_attrs[] =
	{
		&dyn_fsync_active_attribute.attr,
		&dyn_fsync_version_attribute.attr,
		&dyn_fsync_powersuspend_attribute.attr,
		NULL,
	};

static struct attribute_group dyn_fsync_active_attr_group =
	{
		.attrs = dyn_fsync_active_attrs,
	};

static struct kobject *dyn_fsync_kobj;

static void dyn_fsync_force_flush(void)
{
	/* flush all outstanding buffers */
	wakeup_flusher_threads(0, WB_REASON_SYNC);
	sync_filesystems(0);
	sync_filesystems(1);
}

static void dyn_fsync_power_suspend(void)
{
	mutex_lock(&fsync_mutex);
	if (dyn_fsync_active) {
		lcd_notify_suspend_active = true;
		dyn_fsync_force_flush();
	}
	mutex_unlock(&fsync_mutex);
}

static void dyn_fsync_resume(void)
{
	mutex_lock(&fsync_mutex);
	lcd_notify_suspend_active = false;
	mutex_unlock(&fsync_mutex);
}

static int dyn_fsync_panic_event(struct notifier_block *this,
		unsigned long event, void *ptr)
{
	lcd_notify_suspend_active = true;
	dyn_fsync_force_flush();
	//pr_warn("dyn fsync: panic: force flush!\n");

	return NOTIFY_DONE;
}

static struct notifier_block dyn_fsync_panic_block = {
	.notifier_call  = dyn_fsync_panic_event,
	.priority       = INT_MAX,
};

static int dyn_fsync_notify_sys(struct notifier_block *this, unsigned long code,
				void *unused)
{
	if (code == SYS_DOWN || code == SYS_HALT) {
		lcd_notify_suspend_active = true;
		dyn_fsync_force_flush();
		//pr_warn("dyn fsync: reboot: force flush!\n");
	}
	return NOTIFY_DONE;
}

static struct notifier_block dyn_fsync_notifier = {
	.notifier_call = dyn_fsync_notify_sys,
};

static int lcd_notifier_callback(struct notifier_block *nb,
                                 unsigned long event, void *data)
{
       switch (event) {
       case LCD_EVENT_ON_START:
			dyn_fsync_resume();
			pr_info("dyn sync: resume called\n");
               break;
       case LCD_EVENT_ON_END:
               break;
       case LCD_EVENT_OFF_START:
               break;
       case LCD_EVENT_OFF_END:
			dyn_fsync_power_suspend();
			pr_info("dyn sync: suspend called\n");
               break;
       default:
               break;
       }

       return 0;
}

static int dyn_fsync_init(void)
{
	int sysfs_result;

	lcd_worker_dyn_fsync.notifier_call = lcd_notifier_callback;
	
	lcd_register_client(&lcd_worker_dyn_fsync);
	register_reboot_notifier(&dyn_fsync_notifier);
	atomic_notifier_chain_register(&panic_notifier_list,
		&dyn_fsync_panic_block);

	dyn_fsync_kobj = kobject_create_and_add("dyn_fsync", kernel_kobj);
	if (!dyn_fsync_kobj) {
		pr_err("%s dyn_fsync kobject create failed!\n", __FUNCTION__);
		return -ENOMEM;
        }

	sysfs_result = sysfs_create_group(dyn_fsync_kobj,
			&dyn_fsync_active_attr_group);

        if (sysfs_result) {
		pr_info("%s dyn_fsync sysfs create failed!\n", __FUNCTION__);
		kobject_put(dyn_fsync_kobj);
	}
	return sysfs_result;
}

static void dyn_fsync_exit(void)
{
	lcd_unregister_client(&lcd_worker_dyn_fsync);
	unregister_reboot_notifier(&dyn_fsync_notifier);
	atomic_notifier_chain_unregister(&panic_notifier_list,
		&dyn_fsync_panic_block);

	if (dyn_fsync_kobj != NULL)
		kobject_put(dyn_fsync_kobj);
}
MODULE_AUTHOR("Paul Reioux <reioux@gmail.com>");
MODULE_AUTHOR("Varun Chitre <varun.chitre15@gmail.com");
module_init(dyn_fsync_init);
module_exit(dyn_fsync_exit);