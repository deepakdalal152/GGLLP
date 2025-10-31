from ayon_server.settings import (
    SettingsField,
    BaseSettingsModel,
    task_types_enum,
)


class ChannelMessage(BaseSettingsModel):
    channels: list[str] = SettingsField(
        default_factory=list,
        title="Channels"
    )
    upload_thumbnail: bool = SettingsField(
        default=True,
        title="Upload thumbnail"
    )
    upload_review: bool = SettingsField(
        default=True,
        title="Upload review"
    )
    message: str = SettingsField(
        "",
        title="Message",
        widget="textarea"
    )


class Profile(BaseSettingsModel):
    product_types: list[str] = SettingsField(
        default_factory=list,
        title="Product types"
    )
    hosts: list[str] = SettingsField(
        default_factory=list,
        title="Hosts"
    )
    task_types: list[str] = SettingsField(
        default_factory=list,
        title="Task types",
        enum_resolver=task_types_enum
    )
    task_names: list[str] = SettingsField(
        default_factory=list,
        title="Task names"
    )
    product_names: list[str] = SettingsField(
    default_factory=list,
    title="Product names"
    )
    review_upload_limit: float = SettingsField(
        50.0,
        title="Upload review maximum file size (MB)")

    _desc = ("Message sent to channel selected by profile. "
             "Message template can contain {} placeholders from anatomyData "
             "or {review_filepath} for too large review files to link only.")
    channel_messages: list[ChannelMessage] = SettingsField(
        default_factory=list,
        title="Messages to channels",
        description=_desc,
        section="Messages"
    )


class CollectSlackFamiliesPlugin(BaseSettingsModel):
    _isGroup = True
    enabled: bool = True
    optional: bool = SettingsField(False, title="Optional")

    profiles: list[Profile] = SettingsField(
        title="Profiles",
        default_factory=Profile
    )


class SlackPublishPlugins(BaseSettingsModel):
    CollectSlackFamilies: CollectSlackFamiliesPlugin = SettingsField(
        title="Notification to Slack",
        default_factory=CollectSlackFamiliesPlugin,
    )
