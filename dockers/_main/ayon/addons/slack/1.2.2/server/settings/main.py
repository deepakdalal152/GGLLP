from ayon_server.settings import SettingsField, BaseSettingsModel

from .publish_plugins import SlackPublishPlugins


class SlackSettings(BaseSettingsModel):
    """Slack project settings."""
    enabled: bool = SettingsField(default=True)
    token: str = SettingsField("", title="Auth Token")

    publish: SlackPublishPlugins = SettingsField(
        title="Publish plugins",
        description="Fill combination of families, task names and hosts "
                    "when to send notification",
    )


DEFAULT_SLACK_SETTING = {
    "token": "",
    "publish": {
        "CollectSlackFamilies": {
            "enabled": True,
            "optional": True,
            "profiles": [
                {
                    "families": [],
                    "hosts": [],
                    "task_types": [],
                    "tasks": [],
                    "subsets": [],
                    "review_upload_limit": 50.0,
                    "channel_messages": []
                }
            ]
        }
    }
}
