import type { Meta, StoryObj } from "@storybook/react-vite";
import type { Form } from "../../hooks/useForm";
import { Input } from "./Input";

const meta = {
  title: "Forms/Input",
  component: Input,
} satisfies Meta<typeof Input>;

export default meta;
type Story = StoryObj<typeof meta>;

type FormFields = {
  name: string | null;
  password: string | null;
};

const form: Form<FormFields> = {
  id: "testForm",
  key: "testForm-0",
  isPending: false,
  isDirty: false,
  action() {},
  updateField() {},
  state: {
    ok: null,
    errors: {},
  },
  fields: {
    name: "Waldo",
    password: null,
  },
};

export const TextInput: Story = {
  args: {
    type: "text",
    field: "name",
    label: "What's your name?",
    help: "You can use whatever name you want, it's just for display purposes.",
    form,
  },
};

export const PasswordInput: Story = {
  args: {
    type: "password",
    field: "password",
    label: "Please share your password",
    help: "Please don't use hunter2.",
    form,
  },
};

export const SelectInput: Story = {
  args: {
    type: "select",
    field: "name",
    label: "Favourite Beatle?",
    options: {
      john: "John Lennon",
      paul: "Paul McCartney",
      george: "George Harrison",
      ringo: "Ringo Starr",
    },
    form,
  },
};

export const InvalidInput: Story = {
  args: {
    type: "text",
    field: "name",
    label: "What's your name?",
    help: "You can use whatever name you want, it's just for display purposes.",
    form: {
      ...form,
      state: {
        ...form.state,
        errors: {
          name: { message: "That's a silly name!" },
        },
      },
    },
  },
};
